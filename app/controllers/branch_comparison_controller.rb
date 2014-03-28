#!/usr/bin/env ruby 
class BranchComparisonController < ApplicationController
  def index
      render :text => 'Usage: <sonar-server>/branch_comparison/base_project/<project_key_or_id>'
  end

  def base_project
    # make sure id/key is specified
    unless params[:id]
      render :text => 'No project key/id specified'
      return
    end
    # find base project
    base_project = Project.by_key(params[:id])
    # same projects with different branches
    project_key_without_branch = base_project.key.split(':')[0,2].join(':')
    projects = Project.all("kee LIKE ?", project_key_without_branch + "%")
    render :json => {'base project' => base_project,
                      'other branches' => projects}
  end
end
