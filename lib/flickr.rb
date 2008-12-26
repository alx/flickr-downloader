%w(fileutils open-uri thread rubygems).each &method(:require)
require "hpricot"

class Flickr
  Photoset = Struct.new(:title, :slug, :photo, :description)
  Photo    = Struct.new(:id, :secret, :title, :url, :thumb, :path)
  
  def initialize(api_key, user_id, storage_dir)
    @api_key, @user_id, @storage_dir = api_key, user_id, storage_dir
  end
  
  def photos_with_tags(tags)
    get("flickr.photos.search", :tags => tags).search(:photo).pmap do |data|
      photo data["id"], data["secret"], data["title"]
    end
  end
  
  def photo(id, secret, title)
    
    original = thumbnail = nil
    photo = get("flickr.photos.getSizes", :photo_id => id)
    
    if photo.at(:sizes)['candownload'].to_i == 1
      photo.search(:size).each do |size| 
        original  = size["source"] if size["label"] == "Original"
        thumbnail = size["source"] if size["label"] == "Square"
      end
    end
    
    Photo.new(id, secret, title, original, thumbnail)
  end
  
  def download_photo(id)
    photo_id, photo_secret = id.split("_")
    photo_title = get("flickr.photos.getInfo", :photo_id => photo_id).at(:title).inner_html
    @photo = Photo.new photo_id, photo_secret, photo_title
    
    get("flickr.photos.getSizes", :photo_id => id).search(:size).each do |size| 
      @photo.url  = size["source"] if size["label"] == "Medium"
    end
    
    @photo.path = File.join(@storage_dir, @photo.id + File.extname(@photo.url))
    `curl #{@photo.url} >#{@photo.path} 2>/dev/null`
    @photo
  end
  
  def zipfile(photoset_id)
    download_photos(photoset_id)
    `cd #{@storage_dir} && zip -r #{photoset_id} #{photoset_id}`
    File.join(@storage_dir, photoset_id.to_s + ".zip")
  end
  
  private
  
    def download_photos(photoset_id)
      FileUtils.mkdir_p File.join(@storage_dir, photoset_id)
      photos_in_set(photoset_id).pmap do |photo|
        File.join(@storage_dir, photoset_id, photo.id.to_s + File.extname(photo.url)).tap do |path|
          `curl #{photo.url} >#{path} 2>/dev/null`
        end
      end
    end
  
    def get(method, query={})
      Hpricot::XML open(url(query.merge(:method => method)))
    end
    
    def url(request={})
      request = { :api_key => @api_key }.merge(request).to_query_string
      "http://api.flickr.com/services/rest/?#{request}"
    end
end

class Hash
  def to_query_string
    inject(nil) do |query, (key,val)|
      [query, "#{key}=#{val}"].compact.join("&")
    end
  end
end

class Array
  # taken from project.ioni.st
  def pmap
    mapped_array = []
    threads      = []
    0.upto(size - 1) do |n|
      threads << Thread.new do
        mapped_array[n] = yield(at(n))
      end
    end
    threads.each {|thread| thread.join}
    mapped_array
  end
end

class Hpricot::Elements
  def pmap(&block)
    to_a.pmap(&block)
  end
end

class Object
  def tap
    yield self
    self
  end
end
