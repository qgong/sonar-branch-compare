require 'uri'

module BranchComparisonHelper
  MEASURE_URL = "/drilldown/measures/"
  ISSUE_URL = "/drilldown/issues/"
  METRICS = {
    'line' => [{:name => 'ncloc', :character => 0, :type => :measure},
              {:name => 'statements', :character => 0, :type => :measure},
              {:name => 'files', :character => 0, :type => :measure},
              {:name => 'classes', :character => 0, :type => :measure},
              {:name => 'functions', :character => 0, :type => :measure},
              {:name => 'lines', :character => 0, :type => :measure}],
    'issue' => [{:name => 'blocker_violations', :character => -1,
                  :type => :issue, :args => {:severity => 'BLOCKER'}},
                {:name => 'critical_violations', :character => -1,
                  :type => :issue, :args => {:severity => 'CRITICAL'}},
                {:name => 'major_violations', :character => -1,
                  :type => :issue, :args => {:severity => 'MAJOR'}},
                {:name => 'minor_violations', :character => -1,
                  :type => :issue, :args => {:severity => 'MINOR'}},
                {:name => 'info_violations', :character => -1,
                  :type => :issue, :args => {:severity => 'INFO'}},
                {:name => 'violations', :character => -1,
                  :type => :issue},
                {:name => 'violations_density', :character => 1,
                  :type => :issue, :args => {:highlight => 'weighted_violations',
                                              :metric => 'weighted_violations'}}],
    'comment' => [{:name => 'comment_lines', :character => 0, :type => :measure},
                  {:name => 'comment_lines_density', :character => 0, :type => :measure}],
    'duplication' => [{:name => 'duplicated_lines', :character => -1, :type => :measure},
                      {:name => 'duplicated_lines_density', :character => -1,
                        :type => :measure, :args => {:highlight => 'duplicated_lines_density',
                                                      :metric => 'duplicated_lines'}},
                      {:name => 'duplicated_blocks', :character => -1, :type => :measure},
                      {:name => 'duplicated_files', :character => -1, :type => :measure}],
    'complexity' => [{:name => 'function_complexity', :character => -1, :type => :measure},
                    {:name => 'class_complexity', :character => -1, :type => :measure},
                    {:name => 'file_complexity', :character => -1, :type => :measure},
                    {:name => 'complexity', :character => -1, :type => :measure}],
  }


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

  def get_latest_snapshot(project_id, version)
    snapshot = Snapshot.first(:conditions => ['project_id = ? AND version = ?',
                                              project_id.to_i, version],
                              :order => 'created_at DESC')
    return snapshot
  end

  def get_project_versions(project_id)
    snapshots = Snapshot.all(:conditions => ['project_id = ?', project_id.to_i])
    versions = snapshots.map {|snapshot| snapshot.version}
    versions = Set.new(versions).to_a
    versions = versions.sort {|a, b| a.to_f <=> b.to_f}.reverse
    return versions
  end

  def get_measure_data(base_snapshot, target_snapshot)
    data = {}
    METRICS.each_pair do |category, array|
      array.each do |hash|
        metric = Metric.by_name(hash[:name])
        base_project_measure = base_snapshot.measure(metric)
        target_project_measure = target_snapshot.measure(metric)

        data[hash[:name]] = {'delta' => nil, 'quality' => nil, 'short_name' => metric.short_name}
        if base_project_measure and target_project_measure
          data[hash[:name]]['base'] = base_project_measure.formatted_value
          data[hash[:name]]['target'] = target_project_measure.formatted_value
          if base_project_measure.value.is_a?(Numeric) and target_project_measure.value.is_a?(Numeric)
            if target_project_measure.value == base_project_measure.value
              data[hash[:name]]['quality'] = 0
            else
              tmp = (target_project_measure.value - base_project_measure.value).round(1)
              # convert floats to integer if no decimal
              tmp = tmp.to_i if tmp.to_i == tmp
              data[hash[:name]]['delta'] = tmp > 0 ? "+#{tmp}" : "#{tmp}"
              data[hash[:name]]['quality'] = (tmp > 0 ? 1 : -1) * hash[:character]
            end
          end
        else
          data[hash[:name]] = { 'base' => base_project_measure ? base_project_measure.formatted_value : nil,
                                'target' => target_project_measure ? target_project_measure.formatted_value : nil,
                                'delta' => nil,
                                'quality' => 0,
                                'short_name' => metric.short_name}
        end
      end
    end
    return data
  end
end
