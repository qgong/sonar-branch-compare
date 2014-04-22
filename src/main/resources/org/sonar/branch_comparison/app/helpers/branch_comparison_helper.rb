require 'uri'

module BranchComparisonHelper
  MEASURE_URL = "/drilldown/measures/"
  ISSUE_URL = "/drilldown/issues/"

  def get_url(metrics, category, metric_name, args)
    hash = (metrics[category].select {|item| item[:name] == metric_name})[0]
    prefix = case hash[:type]
      when :measure
        MEASURE_URL
      when :issue
        ISSUE_URL
    end
    if hash[:args]
      args = args.merge(hash[:args])
    end
    project_id = args.delete(:id)
    tmp = []
    args.each do |key, value|
      tmp.push("#{key}=#{URI.encode(value)}")
    end
    url = "#{prefix}#{project_id}"
    url << "?#{tmp.join('&')}" unless tmp.empty?
    return url
  end

  def url_encode(url)
    return URI.encode(url)
  end
end
