#!/usr/bin/env ruby 
require 'set'
require 'json'

class BranchComparisonController < ApplicationController
  def index
    begin
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
    @base_project = Project.by_key(params[:id])
    if @base_project == nil
      render :text => "Project #{params[:id]} doesn't exist"
      return
    end

    # find other branches
    @target_projects = self._get_branches(@base_project.key, target_branch_names)
    # find enabled metrics
    @metrics = Metric.all.select {|metric| metric.enabled}
    #@metrics = [Metric.by_id(1)]
    @metrics.sort! {|a, b| a.name <=> b.name}
    # find all available versions for each project
    @versions = {}
    [@base_project].concat(@target_projects).map {|project| project.id}.each do |id|
      @versions[id] = self._get_project_versions(id)
    end
    if @versions[@base_project.id].empty?
      render :text => "Base project #{@base_project.id} has no snapshots"
      return
    end
    @base_project_measure_data = self._get_measure_data(@base_project,
                                                        @versions[@base_project.id][0],
                                                        @metrics)
    @target_projects_measure_data = {}
    @target_projects.each do |project|
        @target_projects_measure_data[project.id] = self._get_measure_data(project,
                                                                            @versions[project.id][0],
                                                                            @metrics)
    end

    rescue => e
      render :text => e.backtrace.join("\n")
    end
  end

  def _get_project_versions(id)
    snapshots = Snapshot.all(:conditions => ['project_id = ?', id.to_i])
    versions = snapshots.map {|snapshot| snapshot.version}
    versions = Set.new(versions).to_a
    versions = versions.sort {|a, b| a.to_f <=> b.to_f}.reverse
    return versions
  end

  # get the other branches of a project
  def _get_branches(project_key, target_branches=nil)
    # get project key(without branch name)
    project_key_without_branch = project_key.split(':')[0,2].join(':')
    sql_template = "kee LIKE :key_pattern AND kee != :base_branch_key
                    AND root_id IS NULL"
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
    target_branches.map! {|item| Project.by_key(item.id)}
    return target_branches
  end

  # get latest snapshot of a specific version
  def _get_latest_snapshot(project_id, version)
    snapshot = Snapshot.first(:conditions => ['project_id = ? AND version = ?',
                                              project_id.to_i, version],
                              :order => 'created_at DESC')
    return snapshot
  end

  def _get_measure_data(project, version, metrics)
    # find snapshot
    snapshot = self._get_latest_snapshot(project.id, version)
    if snapshot.nil?
      render :json => nil
      return
    end
    # calculate result for each metric
    measure_data = {}
    metrics.each do |metric|
      project_measure = snapshot.measure(metric)
      if project_measure
        measure_data[metric.id] = [project_measure.formatted_value, project_measure.value]
      else
        measure_data[metric.id] = [nil, nil]
      end
    end
    data = {'id' => project.id,
            'name' => project.name(true),
            'version' => version,
            'created_at' => snapshot.created_at,
            'measure_data' => measure_data}
    return data
  end

  # params[:id]         project id
  # params['version']   project version
  # params['metrics']   metric ids
  def get_measure_data
    project = Project.by_key(params[:id])
    unless project
      render :json => nil
    end
    metrics = params['metrics'].split(',').map {|id| Metric.by_id(id.to_i)}
    data = self._get_measure_data(project, params['version'], metrics)
    render :json => data
  end

  def compare
  end
end
