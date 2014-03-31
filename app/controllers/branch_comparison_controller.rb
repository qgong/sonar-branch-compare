#!/usr/bin/env ruby 
require 'json'

class BranchComparisonController < ApplicationController
  def index
    # make sure id/key is specified
    unless params[:id]
      render :text => 'Usage: /branch_comparison/<base_project_id_or_key>?target_branches=<branch1>,<branch2>'
      return
    end
    # get target branches
    if params.has_key?(:target_branches)
      unless params[:target_branches] =~ /[^,]+(,[^,]+)*/i
        render :text => 'Multiple branches should be separated by comma'
        return
      end
      target_branches = params[:target_branches].split(',')
    else
      target_branches = nil
    end
    # find base project
    base_project = Project.by_key(params[:id])
    if base_project == nil
      render :text => "Project #{params[:id]} doesn't exist"
      return
    end
    # find other branches
    other_branches = self._get_branches(base_project.key, target_branches)
    # generate result hash
    @snapshots = []
    projects = [base_project].concat(other_branches)
    projects.each do |project|
      item = {}
      snapshots = self._get_snapshots(project.id)
      snapshots.each do |snapshot|
        unless item[snapshot.version]
          item[snapshot.version] = []
        end
        item[snapshot.version].push(snapshot)
      end
      # find the latest one
      item.each_pair do |version, snapshots|
        latest_time = Time.at(0)
        latest_snapshot = nil
        snapshots.each do |snapshot|
          if snapshot.created_at > latest_time
            latest_time = snapshot.created_at
            latest_snapshot = snapshot
          end
        end
        item[version] = latest_snapshot
      end
      # push hash data to result
      @snapshots.push(item)
    end

    begin
      render :json => {'snapshots' => @snapshots}
    rescue => e
      render :text => e
    end
  end

  # get the other branches of a project
  def _get_branches(project_key, target_branches=nil)
    # get project key(without branch name)
    project_key_without_branch = project_key.split(':')[0,2].join(':')
    sql_template = "kee LIKE :key_pattern AND kee != :base_project_key
                    AND root_id IS NULL"
    sql_params = {:key_pattern => "#{project_key_without_branch}%",
                  :base_project_key => project_key}
    if target_branches and not target_branches.empty?
      sql_template << " AND kee IN (:other_branch_keys)"
      sql_params[:other_branch_keys] = target_branches.map do |branch_name|
        [project_key_without_branch, branch_name].join(':')
      end
    end
    # filter projects
    other_branches = Project.all(:conditions => [sql_template, sql_params],
                                  :order => "kee")
    return other_branches
  end

  def _get_snapshots(project_id)
    snapshots = Snapshot.all(:conditions => ['project_id = ?', project_id])
    return snapshots
  end
end
