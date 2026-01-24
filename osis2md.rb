#!/usr/bin/env ruby

# Converts OSIS XML files into Markdown text.
# Supports footnotes, formatting options, output modes (paragraph and reader's), etc.
# Use `--help` to see all options.
# Default output directory: markdown/

require 'fileutils'
require 'nokogiri'
require 'optparse'

def read_osis_xml(path)
  begin
    File.read(path, encoding: 'utf-8')
  rescue Errno::ENOENT
    STDERR.puts "Error: OSIS source not found: #{path}"
    exit 1
  rescue => exc
    STDERR.puts "Error: unable to read OSIS source: #{exc}"
    exit 1
  end
end

def build_book_header(shortTitle, book)
  text = []
  if $FRONTMATTER == 1
    if $JAPANESE_MODE == 0
      text << "---\ntitle: '#{shortTitle}'\ntemplate: bible\nsimplesearch:\n    process: false\n---\n\n"
    else
      text << "---\ntitle: '#{shortTitle}'\ntemplate: bible.ja\nsimplesearch:\n    process: false\nmarkdown:\n    extra: true\n---\n\n"
    end
    titleHeader = "# " + shortTitle
    text << "#{titleHeader}\n\n"
  end
  if $FRONTMATTER == 0
    titleHeader = "# " + shortTitle
    text << "#{titleHeader}\n\n"
  end
  titleHeader = "### " + book.at_css('title').text
  text << "#{titleHeader}\n"
  text
end

def handle_title(part, titleType)
  if ['chapter', 'sub'].include?(titleType)
    level = titleType == 'chapter' ? '##' : '###'
    text = part.text
    text = text.capitalize if $JAPANESE_MODE == 0 && $CAPITALIZE_CHATPER_TITLES == 1
    return "#{level} #{text}"
  elsif titleType == 'acrostic'
    acrosticHeader = '#### ' + '<bdi dir="ltr">' + part.text + '</bdi>'
    if part.text == 'א ALEPH.'
      return "#{acrosticHeader}\n"
    else
      return "\n#{acrosticHeader}\n"
    end
  else
    ''
  end
end

def handle_psalm_title(part)
  psalmTitle = part.children
  puts psalmTitle if $DEBUG_MODE == 1
  text = []
  psalmTitle.each do |p|
    if p.element? && p.name == 'transChange'
      text << "<em>#{p.text}</em>"
    elsif p.element? && p.name == 'divineName'
      text << '<span class="small-caps">' + p.text + '</span>'
    else
      text << p.to_s
    end
  end
  "<div class=\"psalm-title\">" + text.join + "</div>\n\n"
end

def build_verse_number(verseNumber, acrosticMarker)
  if $READERS_MODE == 0
    if (verseNumber == 1 || acrosticMarker == 1) && $NO_DROP_CAPS == 0
      ''
    elsif $PARAGRAPH_MODE == 1
      '<span class="verse-number-super">' + verseNumber.to_s + '</span>'
    else
      '<span class="verse-number">' + verseNumber.to_s + '&ensp;</span>'
    end
  else
    ''
  end
end

def handle_verse_start(verseNumberSup, nextChapterPart, acrosticMarker)
  if $JAPANESE_MODE == 0 && $NO_PILCROWS == 0 && nextChapterPart && nextChapterPart.element? && nextChapterPart.name == 'milestone' && acrosticMarker == 0
    return "#{verseNumberSup}¶ "
  elsif ($PARAGRAPH_MODE == 1 || $READERS_MODE == 1) && nextChapterPart && nextChapterPart.element? && nextChapterPart.name == 'milestone'
    return "\n#{verseNumberSup}"
  else
    verseNumberSup
  end
end

def process_note_content(noteElement)
  content = []
  noteElement.children.each do |child|
    next if child.element? && child.name == 'reference'

    if child.element? && child.name == 'hi' && child['type'] == 'bold'
      content << "**#{child.text}**"
    else
      content << child.text
    end
  end
  content.join.lstrip
end

def process_chapter(chapter, text, footnotes)
  verseNumber = 0
  acrosticMarker = 0
  # Cache the chapter's contents so they don't have to be fetched multiple times
  chapterParts = chapter.children
  chapterParts.each_with_index do |chapterPart, index|
    if chapterPart.element? && chapterPart.name == 'title' && chapterPart['type'] == 'chapter'
      chapterHeader = handle_title(chapterPart, 'chapter')
      text << "#{chapterHeader}\n"
      puts chapterHeader if $DEBUG_MODE == 1
      acrosticMarker = 0
    elsif chapterPart.element? && chapterPart.name == 'title' && chapterPart['type'] == 'sub'
      # Book titles in Psalms
      chapterHeader = handle_title(chapterPart, 'sub')
      text << "#{chapterHeader}\n"
      puts chapterHeader if $DEBUG_MODE == 1
      acrosticMarker = 0
    elsif chapterPart.element? && chapterPart.name == 'title' && chapterPart['type'] == 'acrostic'
      acrosticHeader = handle_title(chapterPart, 'acrostic')
      text << acrosticHeader
      acrosticMarker = 1
    elsif chapterPart.element? && chapterPart.name == 'title' && (chapterPart['type'] == 'psalm' || (chapterPart['canonical'] == 'true' && chapterPart['type'] == 'psalm'))
      psalm_text = handle_psalm_title(chapterPart)
      text << psalm_text
      acrosticMarker = 0
    elsif chapterPart.element? && chapterPart.name == 'verse' && chapterPart.has_attribute?('osisID')
      verseNumber += 1
      verseNumberSup = build_verse_number(verseNumber, acrosticMarker)
      nextChapterPart = chapter.children[index + 1] if index + 1 < chapter.children.size
      verse_start = handle_verse_start(verseNumberSup, nextChapterPart, acrosticMarker)
      text << verse_start
      acrosticMarker = 0
    elsif chapterPart.element? && chapterPart.name == 'note'
      if $PROCESS_FOOTNOTES == 1
        # Add a markdown footnote number directly to the text
        footnoteNumber = footnotes.size + 1
        text << "[^#{footnoteNumber}]"
        # Put the footnote text into the footnotes array, so we can use it later
        footnotes << process_note_content(chapterPart)
        puts chapterPart.text.split(' ')[1] if $DEBUG_MODE == 1
      end
    elsif chapterPart.element? && chapterPart.name == 'transChange'
      italic = '_' + chapterPart.text + '_'
      text << italic
      puts italic if $DEBUG_MODE == 1
    elsif chapterPart.element? && chapterPart.name == 'hi' && chapterPart['type'] == 'bold'
      bold = '**' + chapterPart.text + '**'
      text << bold
      puts bold if $DEBUG_MODE == 1
    elsif chapterPart.element? && chapterPart.name == 'verse' && chapterPart.has_attribute?('eID')
      # Insert two spaces at the end of a verse for markdown line breaks
      text << '  ' if $PARAGRAPH_MODE == 0 && $READERS_MODE == 0
    elsif chapterPart.element? && chapterPart.name == 'milestone'
      # Skip milestone (pilcrow) tags as they are processed in `handle_verse_start`
    elsif chapterPart.element? && chapterPart.name == 'divineName'
      text << '<span class="small-caps">' + chapterPart.text + '</span>'
    else
      # Newlines and regular text go here
      # Remove preceeding tabs that some OSIS files use for readability
      text << chapterPart.to_s.gsub(/^(\t+)/m, '')
      puts chapterPart if $DEBUG_MODE == 1
    end
  end
end

def append_colophon(text, book)
  return text unless book.at('div') && book.at('div')['type'] == 'colophon'
  colophon = book.at_css('div').children
  puts colophon if $DEBUG_MODE == 1
  text << "\n<div class=\"colophon\">"
  colophon.each do |part|
    if part.element? && part.name == 'transChange'
      text << '<em>' + part.text + '</em>'
    else
      text << part.to_s
    end
  end
  text << "</div>\n"
  text
end

def append_footnotes(text, footnotes)
  return text unless $PROCESS_FOOTNOTES == 1
  # Add a couple newlines to separate footnotes from the main text
  text << "\n\n"
  footnoteNumber = 0
  footnotes.each do |footnote|
    footnoteNumber += 1
    footnoteReference = "[^#{footnoteNumber}]: #{footnote}"
    text << "#{footnoteReference}  \n"
    puts footnoteReference if $DEBUG_MODE == 1
  end
  text
end

def write_markdown(path, text)
  begin
    File.write(path, text, encoding: 'utf-8')
  rescue => exc
    STDERR.puts "Error: unable to write markdown file #{path}: #{exc}"
    exit 1
  end
end

def process_book(book, markdownDir, bookIndex)
  shortTitle = book.at_css('title')['short']
  puts "Book: " + book['osisID'] if $DEBUG_MODE == 1
  puts "index is: #{bookIndex}" if $DEBUG_MODE == 1
  fileName = shortTitle.downcase.tr(' ', '_')
  puts fileName if $DEBUG_MODE == 1
  folderName = format('%02d', bookIndex + 1) + '_' + fileName
  markdownPath = File.join(markdownDir, folderName)
  FileUtils.mkdir_p(markdownPath)

  text = build_book_header(shortTitle, book)
  puts 'Processing: ' + shortTitle

  footnotes = []
  book.search('chapter').each do |chapter|
    process_chapter(chapter, text, footnotes)
  end

  text = append_colophon(text, book)
  text = append_footnotes(text, footnotes) if footnotes.any?

  output_path = File.join(markdownDir, folderName, "#{fileName}.md")
  write_markdown(output_path, text.join)
end

def main
  options = {}
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] OSIS_FILE"
    opts.on('-h', '--help', 'Display this help') do
      puts opts
      exit
    end
    opts.on('-d', '--debug', 'Enable debug mode') { options[:debug] = true }
    opts.on('-f', '--frontmatter', 'Enable Grav frontmatter') { options[:frontmatter] = true }
    opts.on('-n', '--process-footnotes', 'Process footnotes') { options[:process_footnotes] = true }
    opts.on('-c', '--no-drop-caps', 'Disable drop caps') { options[:no_drop_caps] = true }
    opts.on('-p', '--no-pilcrows', 'Disable pilcrows') { options[:no_pilcrows] = true }
    opts.on('-t', '--capitalize-chapter-titles', 'Capitalize chapter titles') { options[:capitalize_chapter_titles] = true }
    opts.on('-g', '--paragraph-mode', 'Enable paragraph mode (mutually exclusive with --readers-mode)') { options[:paragraph_mode] = true }
    opts.on('-r', '--readers-mode', 'Enable reader\'s mode (mutually exclusive with --paragraph-mode)') { options[:readers_mode] = true }
    opts.on('-o', '--output-dir DIR', 'Output directory (default: markdown/)') { |dir| options[:output_dir] = dir }
  end
  optparse.parse!

  $DEBUG_MODE = options[:debug] ? 1 : 0
  $FRONTMATTER = options[:frontmatter] ? 1 : 0
  $PROCESS_FOOTNOTES = options[:process_footnotes] ? 1 : 0
  $NO_DROP_CAPS = options[:no_drop_caps] ? 1 : 0
  $NO_PILCROWS = options[:no_pilcrows] ? 1 : 0
  $CAPITALIZE_CHATPER_TITLES = options[:capitalize_chapter_titles] ? 1 : 0
  $PARAGRAPH_MODE = options[:paragraph_mode] ? 1 : 0
  $READERS_MODE = options[:readers_mode] ? 1 : 0
  $MARKDOWN_DIR = options[:output_dir] || 'markdown/'

  if $PARAGRAPH_MODE == 1 && $READERS_MODE == 1
    STDERR.puts "Error: --paragraph-mode and --readers-mode cannot be used together."
    puts optparse
    exit 1
  end
  
  if ARGV.empty?
    STDERR.puts "Error: OSIS_FILE is required."
    puts optparse
    exit 1
  end
  osis_source = ARGV[0]

  $JAPANESE_MODE = osis_source.include?('jap') ? 1 : 0
  puts "Japanese mode enabled" if $JAPANESE_MODE == 1
  
  osisFile = read_osis_xml(osis_source)
  bibleText = Nokogiri::XML(osisFile)
  FileUtils.mkdir_p($MARKDOWN_DIR)
  bookTags = bibleText.css('div').select { |tag| tag.element? && tag['type'] && tag['osisID'] && tag['canonical'] }

  bookTags.each_with_index do |book, index|
    process_book(book, $MARKDOWN_DIR, index)
  end
end

if __FILE__ == $0
  main
end
