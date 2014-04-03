#!/usr/bin/env ruby 
require 'json'

class BranchComparisonController < ApplicationController
  def index
    # make sure id/key is specified
    unless params[:id]
      render :text => 'Usage: /branch_comparison/<base_branch_id_or_key>?target_branches=<branch1>,<branch2>'
      return
    end
    # get target branches
    if params.has_key?(:target_branches)
      unless params[:target_branches] =~ /[^,]+(,[^,]+)*/i
        render :text => 'Multiple branches should be separated by comma'
        return
      end
      target_branch_names = params[:target_branches].split(',')
    else
      target_branch_names = nil
    end
    # find base project
    base_branch = Project.by_key(params[:id])
    if base_branch == nil
      render :text => "Project #{params[:id]} doesn't exist"
      return
    end
    begin
    # find other branches
    target_branches = self._get_branches(base_branch.key, target_branch_names)
    # find snapshots
    @target_projects = []
    [base_branch].concat(target_branches).each do |project|
      data = {:id => project.id,
              :name => project.name(true),
              :key => project.key,
              :snapshots => self._get_latest_snapshot(project.id)}
      data[:versions] = data[:snapshots].keys.sort do |a, b|
        a.to_f <=> b.to_f
      end.reverse
      @target_projects.push(data)
    end
    # find enabled metrics
    @metrics = Metric.all.select {|metric| metric.enabled}
    # remove metrics with no values
    @metrics = @metrics.select do |metric|
      result = false
      @target_projects.each do |data|
        data[:snapshots].each_pair do |version, snapshot|
          value = snapshot.measure(metric)
          if value.is_a?(String) and not value.empty?
            result = true
            break
          elsif not value.nil?
            result = true
            break
          end
        end
        break if result
      end
      result
    end
    @base_project = @target_projects.delete_at(0)
    @metrics.sort! {|a, b| a.name <=> b.name}

    #render :json => @base_project

    rescue => e
      render :text => e
    end
  end

  # get the other branches of a project
  def _get_branches(project_key, target_branches=nil)
    # get project key(without branch name)
    project_key_without_branch = project_key.split(':')[0,2].join(':')
    sql_template = "kee LIKE :key_pattern AND kee != :base_branch_key"
    sql_params = {:key_pattern => "#{project_key_without_branch}%",
                  :base_branch_key => project_key}
    if target_branches and not target_branches.empty?
      sql_template << " AND kee IN (:target_branch_keys)"
      sql_params[:target_branch_keys] = target_branches.map do |branch_name|
        [project_key_without_branch, branch_name].join(':')
      end
    end
    # filter projects
    target_branches = Project.all(:conditions => [sql_template, sql_params],
                                  :order => "kee ASC")
    return target_branches
  end

  # get latest snapshot of a specific version
  def _get_latest_snapshot(project_id, version)
    snapshot = Snapshot.first(:conditions => ['project_id = ? AND version = ?',
                                              project_id, version],
                              :order => 'created_at DESC')
    return snapshot
  end

  def get_project
    # search for project
    project = Project.by_key(params['project_id'].to_i)
    if project.nil?
      render :json => {'status' => false,
                      'error' => "Project #{params['project_id']} not found"}
      return
    end
    # find snapshot
    snapshot = self._get_latest_snapshot(params['project_id'].to_i, params['version'])
    # calculate result for each metric
    json = {'name' => project.name(true), 'metrics' => {},
            'status' => true}
    params['metrics'].each do |metric_id|
      metric = Metric.by_id(metric_id)
      if metric
        json['metrics'][metric_id] = snapshot.measure(metric_id)
      else
        render :json => {'status' => false,
                        'error' => "Metric #{metric_id} not found"}
        return
      end
    end
    render :json => json
  end
end
