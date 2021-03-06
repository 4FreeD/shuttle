# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'rails_helper'
require 'rake'

RSpec.describe 'maintenance' do
  before :all do
    Rake.application.rake_require "tasks/maintenance/cleanup_repos"
    Rake::Task.define_task(:environment)
  end

  context "[UNIT TESTS]" do
    describe "#git_projects_with_unique_repos" do
      it "returns all projects, excluding non-git-based ones and ones with duplicate repository_urls" do
        project1 = FactoryBot.create(:project, repository_url: "repo1")
        project2 = FactoryBot.create(:project, repository_url: "repo2")
        project3 = FactoryBot.create(:project, repository_url: "repo2")
        non_git_based = FactoryBot.create(:project, repository_url: nil)

        expect(ReposCleaner.new.git_projects_with_unique_repos.to_a).to match_array([project1, project2])
      end
    end

    describe "#gc_and_remote_prune" do
      it "prunes remote-tracking branches from working_repo that are deleted from the remote repo" do
        project = FactoryBot.create(:project, :light)
        project.working_repo.references.create("refs/remotes/origin/non-existent-branch", '67adce6e5e7e2cae5621b8e86d4ebdd20b5ce264')

        expect(project.working_repo.branches.each_name(:remote)).to include('origin/non-existent-branch')
        ReposCleaner.new.gc_and_remote_prune(project.working_repo)
        expect(project.working_repo.branches.each_name(:remote)).to_not include('origin/non-existent-branch')
      end
    end
  end

  context "[INTEGRATION TESTS]" do
    subject { Rake::Task['maintenance:cleanup_repos'].invoke }

    describe 'cleanup_repos' do
      it "prunes remote-tracking branches from repo that are deleted from the remote repo" do
        project = FactoryBot.create(:project, :light)
        project.working_repo.references.create("refs/remotes/origin/non-existent-branch", '67adce6e5e7e2cae5621b8e86d4ebdd20b5ce264')

        expect(project.working_repo.branches.each_name(:remote)).to include('origin/non-existent-branch')
        subject
        expect(project.repo.branches.each_name(:remote)).to_not include('origin/non-existent-branch')
      end
    end
  end
end
