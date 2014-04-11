#!/usr/bin/env ruby 
require 'json'
require 'set'

class BranchComparisonController < ApplicationController
  METRIC_TYPES = { 
    'line' => [['ncloc', 0],
              ['statements', 0],
              ['files', 0],
              ['classes', 0],
              ['functions', 0],
              ['lines', 0]],
    'issue' => [['blocker_violations', -1],
                ['critical_violations', -1],
                ['major_violations', -1],
                ['minor_violations', -1],
                ['info_violations', -1],
                ['violations', -1],
                ['violations_density', 1]],
    'comment' => [['comment_lines', 0],
                  ['comment_lines_density', 0]],
    'duplication' => [['duplicated_lines', -1],
                      ['duplicated_lines_density', -1],
                      ['duplicated_blocks', -1],
                      ['duplicated_files', -1]],
    'complexity' => [['function_complexity', -1],
                    ['class_complexity', -1],
                    ['file_complexity', -1],
                    ['complexity', -1]],
  }

  # params[:id]               id/key of the base project
  # params['target']          id/key of the target project
  # params['base_version']    optional, version of the base project
  # params['target_version']  optional, version of the target project
  def result
    base_project_id = params[:id]
    target_project_id = params['target']
    @base_project = Project.by_key(base_project_id)
    @target_project = Project.by_key(target_project_id)
    unless @base_project and @target_project
      render :text => "Base project #{base_project_id} or target project #{target_project_id} not found!"
      return
    end
    @metrics = {}
    METRIC_TYPES.each_pair do |category, arr|
      @metrics[category] = arr.map do |metric_name, type|
        metric = Metric.by_name(metric_name)
        [metric, type]
      end
    end
    @metric_layout = [['line', 'comment', 'complexity'],
                      ['issue', 'duplication']]
    @base_version_list = self._get_project_versions(@base_project.id)
    @target_version_list = self._get_project_versions(@target_project.id)
    @base_version = params['base_version'] ? params['base_version'] : @base_version_list[0]
    @target_version = params['target_version'] ? params['target_version'] : @target_version_list[0]
    unless @base_version_list.include?(@base_version) and @target_version_list.include?(@target_version)
      render :text => "Version not found: base #{@base_version}, target: #{@target_version}"
    end
    @measure_data = self._get_measure_data(@base_project.id, @base_version_list[0],
                                            @target_project.id, @target_version_list[0])
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
    METRIC_TYPES.each_pair do |category, arr|
      arr.each do |metric_name, metric_type|
        metric = Metric.by_name(metric_name)
        base_snapshot = self._get_latest_snapshot(base_project_id, base_project_version)
        base_project_measure = base_snapshot.measure(metric)
        target_snapshot = self._get_latest_snapshot(target_project_id, target_project_version)
        target_project_measure = target_snapshot.measure(metric)

        data[metric_name] = {'delta' => nil, 'quality' => nil}
        if base_project_measure and target_project_measure
          data[metric_name]['base'] = base_project_measure.formatted_value
          data[metric_name]['target'] = target_project_measure.formatted_value
          if base_project_measure.value.is_a?(Numeric) and target_project_measure.value.is_a?(Numeric)
            if target_project_measure.value == base_project_measure.value
              data[metric_name]['quality'] = 0
            else
              tmp = (target_project_measure.value - base_project_measure.value).round(1)
              tmp = tmp.to_i if tmp.to_i == tmp
              data[metric_name]['delta'] = tmp > 0 ? "+#{tmp}" : "#{tmp}"
              data[metric_name]['quality'] = (tmp > 0 ? 1 : -1) * metric_type
            end
          end
        else
          data[metric_name] = { 'base' => base_project_measure ? base_project_measure.formatted_value : nil,
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
