# encoding: utf-8
require 'fileutils'
class WordToMarkdown
  class Document
    class NotFoundError < StandardError; end

    attr_reader :path, :raw_html, :tmpdir, :plain_txt

    def initialize(path, options={normalize: true})
      @path = File.expand_path path, Dir.pwd
      @options = options
      @tmpdir = options[:tmpdir] || Dir.mktmpdir

      raise NotFoundError, "File #{@path} does not exist" unless File.exist?(@path)
    end

    def extension
      File.extname path
    end

    def tree
      @tree ||= begin
        tree = Nokogiri::HTML(@options[:normalize] ? normalized_html : raw_html)
        tree.css("title").remove
        tree
      end
    end

    # Returns the html representation of the document
    def html
      tree.to_html.gsub("</li>\n", "</li>")
    end

    # Returns the markdown representation of the document
    def to_s
      @markdown ||= scrub_whitespace(ReverseMarkdown.convert(html, WordToMarkdown::REVERSE_MARKDOWN_OPTIONS))
    end

    # Determine the document encoding
    #
    # html - the raw html export
    #
    # Returns the encoding, defaulting to "UTF-8"
    def encoding
      match = raw_html.encode("UTF-8", :invalid => :replace, :replace => "").match(/charset=([^\"]+)/)
      if match
        match[1].sub("macintosh", "MacRoman")
      else
        "UTF-8"
      end
    end

    def plain_text
      @plain_text ||= begin
        WordToMarkdown::run_command '--headless', '--convert-to', '"txt:Text (encoded):UTF8"', path, '--outdir', tmpdir
        dest_filename = File.basename(path).gsub(/#{Regexp.escape(extension)}$/, ".txt")
        txt_path = File.expand_path(dest_filename, tmpdir)
        txt = File.read txt_path, encoding: 'utf-8'
        File.delete txt_path
        txt
      end
    end

    private

    # Perform pre-processing normalization
    #
    # html - the raw html input from the export
    #
    # Returns the normalized html
    def normalized_html
      html = raw_html.force_encoding(encoding)
      html = html.encode("UTF-8", :invalid => :replace, :replace => "")
      html = Premailer.new(html, :with_html_string => true, :input_encoding => "UTF-8").to_inline_css
      html.gsub! /\n|\r/," "         # Remove linebreaks
      html.gsub! /“|”/, '"'          # Straighten curly double quotes
      html.gsub! /‘|’/, "'"          # Straighten curly single quotes
      html.gsub! />\s+</, "><"       # Remove extra whitespace between tags
      html
    end

    # Perform post-processing normalization of certain Word quirks
    #
    # string - the markdown representation of the document
    #
    # Returns the normalized markdown
    def scrub_whitespace(string)
      string.gsub!("&nbsp;", " ")                     # HTML encoded spaces
      string.sub!(/\A[[:space:]]+/,'')                # document leading whitespace
      string.sub!(/[[:space:]]+\z/,'')                # document trailing whitespace
      string.gsub!(/([ ]+)$/, '')                     # line trailing whitespace
      string.gsub!(/\n\n\n\n/,"\n\n")                 # Quadruple line breaks
      string.gsub!(/\u00A0/, "")                      # Unicode non-breaking spaces, injected as tabs
      string
    end

    def dest_path
      dest_filename = File.basename(path).gsub(/#{Regexp.escape(extension)}$/, ".html")
      File.expand_path(dest_filename, tmpdir)
    end

    def raw_html
      @raw_html ||= begin
        WordToMarkdown::run_command '--headless', '--convert-to', 'html', path, '--outdir', tmpdir
        html = File.read dest_path
        File.delete dest_path
        html
      end
    end
  end
end
