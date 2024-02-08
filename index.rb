require 'faraday'
require 'nokogiri'
require 'fileutils'
require 'json'

# volumes index
BASE_URL = 'http://comic.dragonballcn.com/dragonball_jp_kanzenban.htm'
CACHE_FILE = 'cache'

def get_and_parse url, parser: :html
  body = Faraday.get(url).body

  #puts "parser: #{parser} | url: #{url}"

  if parser == :html
    Nokogiri::HTML(body)
  elsif parser == :xml
    Nokogiri::XML(body)
  end
end

def cache volume, page
  body = {volume: volume.to_i, page: page.to_i}

  File.write(CACHE_FILE, body.to_json)
end

def cached? volume, page = nil
  return false unless File.exists?(CACHE_FILE)

  json = JSON.parse(File.read(CACHE_FILE))

  return json['volume'].to_i > volume.to_i if page.nil?

  json['volume'].to_i >= volume.to_i && json['page'].to_i >= page.to_i
end

volumes = get_and_parse(BASE_URL)

volumes.css('#hdnavli4 a').each.with_index(1) do |volume_link, volume_index|
  # volume

  next if cached?(volume_index)

  volume_url = URI.join(BASE_URL, volume_link['href'])
  puts "volume #{volume_index}: #{volume_url}"

  volume_path = "output/#{volume_index}"
  FileUtils.mkdir_p(volume_path)

  get_and_parse(volume_url).css('.List.Files .ItemThumb a').each.with_index(1) do |page_link, page_index|
    # page

    next if cached?(volume_index, page_index)

    page_url = URI.join(volume_url, page_link['href'])
    puts "page #{page_index}: #{page_url}"

    get_and_parse(page_url, parser: :xml).css('.DisplayItemImage').each do |image_container|
      # image

      image = image_container.content.match(/'(.+)',/).to_a.last
      puts "image: #{image}"

      File.open("#{volume_path}/#{page_index}.jpg", 'wb') { |fp| fp.write(Faraday.get(image).body) }

      cache(volume_index, page_index)
    end
  end
end
