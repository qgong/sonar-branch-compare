#!/usr/bin/env ruby
FILE_DIR = File::expand_path(File::dirname(__FILE__))
require 'openssl'
require 'uri'
require 'net/http'
require "#{FILE_DIR}/digest_auth.rb"

class Rest
  def self.get(url)
    uri = URI(url)
  end

  def self.post
  end

  def self.put
  end

  def self.delete
  end

  def self.request(url, req)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    res = Net::HTTP.new
  end
end
