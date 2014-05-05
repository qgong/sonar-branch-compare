#!/usr/bin/env ruby 
require 'json'
require 'set'
require 'net/smtp'

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


class BranchComparisonController < ApplicationController
  helper BranchComparisonHelper
  include BranchComparisonHelper

  def initialize
    METRICS.each_pair do |key, array|
      array.each do |hash|
        metric = Metric.by_key(hash[:name])
        hash[:short_name] = metric.short_name
      end
    end
  end

  def index
    render :text => 'Branch Comparison Plugin Index Page'
  end

  # params[:id]               id/key of the base project
  # params['target']          id/key of the target project
  # params['base_version']    optional, version of the base project
  # params['target_version']  optional, version of the target project
  def result
    begin

    base_project_id = params[:id]
    target_project_id = params['target']
    @base_project = Project.by_key(base_project_id)
    @target_project = Project.by_key(target_project_id)
    unless @base_project and @target_project
      render :text => "Base project #{base_project_id} or target project #{target_project_id} not found!"
      return
    end
    @metrics = METRICS
    @metric_layout = [['line', 'comment', 'complexity'],
                      ['issue', 'duplication']]
    @base_version_list = self._get_project_versions(@base_project.id)
    @target_version_list = self._get_project_versions(@target_project.id)
    @base_version = params['base_version'] ? params['base_version'] : @base_version_list[0]
    @target_version = params['target_version'] ? params['target_version'] : @target_version_list[0]
    unless @base_version_list.include?(@base_version) and @target_version_list.include?(@target_version)
      render :text => "Version not found: base #{@base_version}, target: #{@target_version}"
    end
    @measure_data = self._get_measure_data(@base_project.id, @base_version,
                                            @target_project.id, @target_version)

    # send email
    if params['email']
      subject = "[sonar] #{@base_project.name(true)} <=> #{@target_project.name(true)}"
      sender = "noreply@redhat.com"
      receiver = params['email'].strip
      html = self._measure_to_html(@base_project, @target_project, @measure_data)
      self._send_email(subject, html, sender, receiver)
    end

    rescue => e
      render :text => e
    end
  end

  def _measure_to_html(base_project, target_project, measure_data)
    css = <<END
<style type="text/css">
  .metric_name {
    width: 20em;
    overflow: hidden;
    border-left: 1px solid;
    border-right: 1px solid;
  }
  .data {
    width: 10em;
    border-right: 1px solid;
  }
  .better {
    background-color: #40FF00;
  }
  .worse {
    background-color: #FE2E2E;
  }
  td {
      text-align: center;
      border-bottom: 1px solid;
  }
</style>
END

    html_template = <<END
<html>
  <head>
    %{css}
  </head>
  <body>
    <table>
      <thead>
        %{thead}
      </thead>
      <tbody>
        %{tbody}
      </tbody>
    </table>
    <a href="%{result_url}">%{link_text}</a>
  </body>
</html>
END
    thead = <<END
<tr>
  <td>#</td>
  <td>#{base_project.branch.to_s}</td>
  <td>#{target_project.branch.to_s}</td>
</tr>
END
    tbody = ''
    METRICS.each_pair do |category, array|
      array.each do |item|
        metric_name = item[:name]
        data = @measure_data[metric_name]
        if data['quality'] == 1
          quality = ' class="better"'
        elsif data['quality'] == -1
          quality = ' class="worse"'
        else
          quality = nil
        end
        if data['delta']
          delta = "(#{data['delta']})"
        else
          delta = nil
        end
        metric = Metric.by_name(metric_name)
        tbody << "<tr#{quality}><td class=\"metric_name\">#{metric.short_name}</td><td class=\"data\">#{data['base']}</td><td class=\"data\">#{data['target']}#{delta}</td></tr>\n"
      end
    end
    link_text = "View comparison result on sonar website"
    result_url = "http://#{request.host}:#{request.port}/branch_comparison/result/#{base_project.id}?target=#{target_project.id}"

    html = html_template % {:css => css, :thead => thead, :tbody => tbody, :result_url => result_url, :link_text => link_text}
    return html
  end

  def _send_email(subject, text, sender, receiver)
    msg = <<MESSAGE_END
From: #{sender}
To: #{receiver}
MIME-Version: 1.0
Content-type: text/html
Subject: #{subject}

#{text}
MESSAGE_END

    Net::SMTP.start('localhost') do |smtp|
      smtp.send_message(msg, "#{ENV['USER']}@#{ENV['HOSTNAME']}", receiver)
    end
  end

  def _get_project_versions(id)
    snapshots = Snapshot.all(:conditions => ['project_id = ?', id.to_i])
    versions = snapshots.map {|snapshot| snapshot.version}
    versions = Set.new(versions).to_a
    versions = versions.sort {|a, b| a.to_f <=> b.to_f}.reverse
    return versions
  end

  def _get_measure_data(base_project_id, base_project_version, target_project_id, target_project_version)
    data = {}
    METRICS.each_pair do |category, array|
      array.each do |hash|
        metric = Metric.by_name(hash[:name])
        base_snapshot = self._get_latest_snapshot(base_project_id, base_project_version)
        base_project_measure = base_snapshot.measure(metric)
        target_snapshot = self._get_latest_snapshot(target_project_id, target_project_version)
        target_project_measure = target_snapshot.measure(metric)

        data[hash[:name]] = {'delta' => nil, 'quality' => nil}
        if base_project_measure and target_project_measure
          data[hash[:name]]['base'] = base_project_measure.formatted_value
          data[hash[:name]]['target'] = target_project_measure.formatted_value
          if base_project_measure.value.is_a?(Numeric) and target_project_measure.value.is_a?(Numeric)
            if target_project_measure.value == base_project_measure.value
              data[hash[:name]]['quality'] = 0
            else
              tmp = (target_project_measure.value - base_project_measure.value).round(1)
              tmp = tmp.to_i if tmp.to_i == tmp
              data[hash[:name]]['delta'] = tmp > 0 ? "+#{tmp}" : "#{tmp}"
              data[hash[:name]]['quality'] = (tmp > 0 ? 1 : -1) * hash[:character]
            end
          end
        else
          data[hash[:name]] = { 'base' => base_project_measure ? base_project_measure.formatted_value : nil,
                                'target' => target_project_measure ? target_project_measure.formatted_value : nil,
                                'delta' => nil,
                                'quality' => nil}
        end
      end
    end
    return data
  end

  # get latest snapshot of a specific version
  def _get_latest_snapshot(project_id, version)
    snapshot = Snapshot.first(:conditions => ['project_id = ? AND version = ?',
                                              project_id.to_i, version],
                              :order => 'created_at DESC')
    return snapshot
  end

end
