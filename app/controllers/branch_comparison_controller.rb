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
    @target_projects = {}
    [base_branch].concat(target_branches).each do |project|
      data = {:name => project.name(true),
              :key => project.key,
              :snapshots => self._get_latest_snapshots(project.id)}
      data[:versions] = data[:snapshots].keys.sort do |a, b|
        a.to_f <=> b.to_f
      end.reverse
      unless data[:snapshots].empty?
        @target_projects[project.id] = data
      end
    end
    # find enabled metrics
    @metrics = Metric.all.select {|metric| metric.enabled}
    # remove metrics with no values
    @metrics = @metrics.select do |metric|
      result = false
      @target_projects.each_pair do |project_id, data|
        data[:snapshots].each_pair do |version, snapshot|
          if snapshot.measure(metric)
            result = true
            break
          end
        end
        break if result
      end
      result
    end
    @base_project = @target_projects.delete(base_branch.id)
    @metrics.sort! {|a, b| a.name <=> b.name}

    rescue => e
      render :text => e
    end
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
                                  :order => "kee")
    return target_branches
  end

  # get latest snapshots of different versions
  def _get_latest_snapshots(project_id)
    hash = {}
    snapshots = Snapshot.all(:conditions => ['project_id = ?', project_id])
    snapshots.each do |snapshot|
      unless hash[snapshot.version]
        hash[snapshot.version] = []
      end
      hash[snapshot.version].push(snapshot)
    end
    # find the latest one
    hash.each_pair do |version, snapshots|
      latest_time = Time.at(0)
      latest_snapshot = nil
      snapshots.each do |snapshot|
        if snapshot.created_at > latest_time
          latest_time = snapshot.created_at
          latest_snapshot = snapshot
        end
      end
      hash[version] = latest_snapshot
    end
    return hash
  end
end
