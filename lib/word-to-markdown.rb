require 'descriptive_statistics'
require 'reverse_markdown'
require 'nokogiri-styles'
require 'sys/proctable'
require 'premailer'
require 'rbconfig'
require 'nokogiri'
require 'tmpdir'
require 'open3'

require_relative 'word-to-markdown/version'
require_relative 'word-to-markdown/document'
require_relative 'word-to-markdown/converter'
require_relative 'nokogiri/xml/element'

class WordToMarkdown

  include Sys

  attr_reader :document, :converter

  REVERSE_MARKDOWN_OPTIONS = {
    unknown_tags: :bypass,
    github_flavored: true
  }

  # Create a new WordToMarkdown object
  #
  # input - a HTML string or path to an HTML file
  #
  # Returns the WordToMarkdown object
  def initialize(path, options={normalize: true})
    @document = WordToMarkdown::Document.new path, options
    @converter = WordToMarkdown::Converter.new @document
    converter.convert!
  end

  # source: https://stackoverflow.com/questions/11784109/detecting-operating-systems-in-ruby
  def self.os
    @os ||= (
    host_os = RbConfig::CONFIG['host_os']
    case host_os
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      :windows
    when /darwin|mac os/
      :macosx
    when /linux/
      :linux
    when /solaris|bsd/
      :unix
    else
      raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
    end
    )
  end

  def self.soffice_path
    case os
    when :macosx
      %w[~/Applications /Applications]
        .map  { |f| File.expand_path(File.join(f, "/LibreOffice.app/Contents/MacOS/soffice")) }
        .find { |f| File.file?(f) }
    when :windows
      'C:\Program Files (x86)\LibreOffice 4\program\soffice.exe'
    else
      "soffice"
    end
  end

  def self.soffice?
    @soffice ||= !(soffice_path.nil? || soffice_version.nil?)
  end

  def self.soffice_open?
    ProcTable.ps.any? { |p| p.exe == soffice_path }
  end

  def self.run_command(*args)
    raise "LibreOffice executable not found" unless soffice?
    raise "LibreOffice already running" if soffice_open?

    output, status = Open3.capture2e(soffice_path, *args)
    raise "Command `#{soffice_path} #{args.join(" ")}` failed: #{output}" if status != 0
    output
  end

  def self.soffice_version
    return if soffice_path.nil?
    output, status = Open3.capture2e(soffice_path, "--version")
    output.strip.sub "LibreOffice ", "" if status == 0
  end

  # Pretty print the class in console
  def inspect
    "<WordToMarkdown path=\"#{@document.path}\">"
  end

  def to_s
    document.to_s
  end
end
