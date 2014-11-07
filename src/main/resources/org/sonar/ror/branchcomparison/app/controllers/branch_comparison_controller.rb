#!/usr/bin/env ruby 
require 'json'
require 'set'
require 'net/smtp'


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
    base_project_id = params[:id]
    target_project_id = params['target']
    # find base and target project
    @base_project = Project.by_key(base_project_id)
    @target_project = Project.by_key(target_project_id)
    unless @base_project
      render :text => "Base project #{base_project_id} not found!"
      return
    end
    unless @target_project
      render :text => "Target project #{target_project_id} not found!"
      return
    end
    @metrics = METRICS
    @metric_layout = [['line', 'comment', 'complexity'],
                      ['issue', 'duplication']]
    # version list
    @base_version_list = self.get_project_versions(@base_project.id)
    @base_version = params['base_version'] ? params['base_version'] : @base_version_list[0]
    unless @base_version_list.include?(@base_version)
      render :text => "Version not found: base #{@base_version}"
      return
    end
    @target_version_list = self.get_project_versions(@target_project.id)
    @target_version = params['target_version'] ? params['target_version'] : @target_version_list[0]
    unless @target_version_list.include?(@target_version)
      render :text => "Version not found: target: #{@target_version}"
      return
    end
    # measure data
    base_snapshot = self.get_latest_snapshot(@base_project.id, @base_version)
    target_snapshot = get_latest_snapshot(@target_project.id, @target_version)
    @measure_data = self.get_measure_data(base_snapshot, target_snapshot)
    if params['format'] == 'json'
      render :json => @measure_data
      return
    end
  end
end
