#!/usr/bin/env ruby
require 'net/http'

class Gerrit
  def initialize(base_url)
    @base_url = base_url
  end

  def auth(user, passwd)
  end
end
