#!/usr/bin/env ruby
require 'cgi'

INPUT  = ARGV[0] || 'example.csv'
OUTPUT = File.basename(INPUT, '.*') + '.html'

def parse_csv(text)
  rows = [[]]
  field = ''
  quoted = false
  i = 0

  while i < text.length
    c = text[i]
    if quoted
      if c == '"' && text[i + 1] != ',' and text[i + 1] != "\n"
        field << '"'
        i += 1
      elsif c == '"'
        quoted = false
      else
        field << c
      end
    elsif c == '"'
      quoted = true
    elsif c == ','
      rows.last << field
      field = ''
    elsif c == "\n"
      rows.last << field
      field = ''
      rows << []
    elsif c != "\r"
      field << c
    end
    i += 1
  end

  rows.last << field
  rows.reject { |row| row.join.empty? }
end

def row_html(cells, tag)
  '  <tr>' + cells.map { |c| "<#{tag}>#{CGI.escapeHTML(c)}</#{tag}>" }.join + "</tr>\n"
end

abort "csv2html: файл не найден: #{INPUT}" unless File.exist?(INPUT)

rows = parse_csv(File.read(INPUT, mode: 'r:bom|utf-8'))
abort "csv2html: в файле нет данных: #{INPUT}" if rows.empty?

header = rows.shift

html = <<~HTML
  <!DOCTYPE html>
  <html lang="ru">
  <head>
  <meta charset="utf-8">
  <title>#{CGI.escapeHTML(File.basename(INPUT))}</title>
  <style>
    table { border-collapse: collapse; font: 15px sans-serif; }
    th, td { border: 1px solid #999; padding: 4px 8px; text-align: left; }
    th { background: #eee; }
  </style>
  </head>
  <body>
  <table>
HTML

html << row_html(header, 'th')
rows.each { |row| html << row_html(row, 'td') }
html << "</table>\n</body>\n</html>\n"

File.write(OUTPUT, html)
puts "Готово -> #{OUTPUT}"
