# osis2md.rb

This is used to create the web pages for the [King James Bible](/library/bibles/king_james_bible) and [Lifeline Japanese New Testament](/library/bibles/lifeline), but that wasn't the original intention for it.


## History

A few years ago, I was using an ereader to read the Bible, but the only ebook versions I could find of the King James would crash my device when searching for words. I wanted to see if I would have the same issue if I created my own version.

In order to start, I needed a good source for the text. I was already familiar with [OSIS](https://en.wikipedia.org/wiki/Open_Scripture_Information_Standard?target=_blank&rel=noopener&rel=noreferrer) from working on the SWORD module of the [Lifeline Japanese New Testament](https://github.com/akaitsurugi/japlifeline?target=_blank&rel=noopener&rel=noreferrer). Most OSIS files for the King James are large at ~30 MB, mainly because of the inclusion of tags for the Greek and Hebrew words. Fortunately, I was able to find [a previous version](https://www.crosswire.org/~dmsmith/kjv2011/?target=_blank&rel=noopener&rel=noreferrer) that didn't include all of these and was only ~8 MB. It still had a few tags that I didn't need, so I removed them. [The result](https://github.com/akaitsurugi/kingjesusbible?target=_blank&rel=noopener&rel=noreferrer) will serve as the base for the [King Jesus Bible](/library/bibles/king_jesus_bible).

This script was originally written in Python. I needed to parse the XML from the OSIS source, and eventually export it to an EPUB file. EPUB is the most popular format for ebooks, and is essentially a website in an archive. The web pages for this site are written in Markdown, and I found that [Pandoc](https://pandoc.org/?target=_blank&rel=noopener&rel=noreferrer) can be used to convert Markdown files to EPUB, PDF, HTML, DOCX, ODT, RTF, and more. So, I figured if I could get the files into Markdown, I could export those to just about any other format I'd use. After creating an EPUB with this method, I quickly confirmed that searching it didn't crash my ereader.

It took me a couple of years to iron out the kinks, as I read a significant portion of the text to verify that the script preserved the words. The major discrepancies have been resolved, but if there is anything missing or corrupted in the text, please [let me know](/about#contribute).

At the beginning of 2026, I refactored it and then experimented with AI[^1] by converting it to Ruby. I wasn't sure if there would be any difference, but I had been thinking about learning Ruby, so I figured it would only serve as an educational exercise. The original Python version used `beautifulsoup` and `lxml` to parse the XML, and the Ruby version uses `nokogiri`. I didn't anticipate how good the end result would be: a more readable script that ran three times as fast as the Python version. I don't plan to (or even desire to) use AI for much, but it introduced me to some basic Ruby concepts. It was fun to see how Ruby looks, and reviewing every line convinced me that I should use Ruby more.


## Usage

```console
$ ruby osis2md.rb --help
Usage: osis2md.rb [options] OSIS_FILE
    -h, --help                       Display this help
    -d, --debug                      Enable debug mode
    -f, --frontmatter                Enable Grav frontmatter
    -n, --process-footnotes          Process footnotes
    -q, --process-quotes             Process quotes
    -c, --no-drop-caps               Disable drop caps
    -p, --no-pilcrows                Disable pilcrows
    -t, --capitalize-chapter-titles  Capitalize chapter titles
    -g, --paragraph-mode             Enable paragraph mode (mutually exclusive with --readers-mode)
    -r, --readers-mode               Enable reader's mode (mutually exclusive with --paragraph-mode)
    -o, --output-dir DIR             Output directory (default: markdown/)

# King James for web pages
$ ruby osis2md.rb -f kingjamesbible.osis.xml
Processing: Genesis
Processing: Exodus
Processing: Leviticus
...

# Automatic Japanese mode if "jap" is in the file name
$ ruby osis2md.rb -f -n japlifeline.osis.xml
Japanese mode enabled
Processing: マタイ
Processing: マルコ
Processing: ルカ
...
```


## Lessons Learned

The OSIS version of the Bible has a lot of data (footnotes, titles, paragraph markers, etc.) in it other than the text. OSIS is a stable, mature schema that can handle any type of formatting you'd need in the Bible.

Git is great for working with the text of the Bible. If Bible translators utilized OSIS with Git, they would have a log with the reasoning behind translation choices and changes, and a source that can easily be converted to many other formats.


[^1]: I state this for transparency of the process, as I don't have a high opinion of AI in general, but I recognize that it can be useful for certain tasks. I reviewed all of the Ruby code, understand it, confirmed that the output 100% matched the Python version, and I fully plan on making future changes myself.
