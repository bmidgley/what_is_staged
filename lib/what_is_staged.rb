#!/usr/bin/env ruby
#
# git log #{branch} -1 --pretty=format:', %an, %aI'

require 'getoptlong'
require 'tty/tree'

def unmerged_branches(branch)
  `git branch -r --no-merged origin/#{branch}`.split("\n").map(&:strip).map{|m| m.gsub('origin/','')}
end

def staged_by(branch, ancestors=[], indent="")
  @contained[branch] ||= begin
    unstaged_branches = unmerged_branches(branch)
    staged = @all_unmerged_branches - unstaged_branches - [branch] - ancestors
    contained_branches = []

    staged.map do |staged_branch|
      contained_branches += staged_by(staged_branch, ancestors + [branch], indent + " ")
    end
    staged - contained_branches
  end
end

def tree_from(branch, detail=nil)
  { "#{branch}#{detail}" => @contained[branch].map{|n| tree_from(n) } }
end

def summarize(staging_branch_name)
  staged = staged_by(staging_branch_name)

  if @verbose || @csv
    data = tree_from(staging_branch_name, `git log origin/#{staging_branch_name} -1 --pretty=format:', %an, %aI'`)
    if @csv
      puts "#{data.keys.first}"
    else
      tree = TTY::Tree.new(data)
      puts tree.render
    end
  else
    puts "#{staged.join("\n")}"
  end
end

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--brief', '-b', GetoptLong::NO_ARGUMENT ],
  [ '--all', '-a', GetoptLong::NO_ARGUMENT ],
  [ '--csv', '-c', GetoptLong::NO_ARGUMENT ],
)

@verbose = true
staging_branch_names = nil

opts.each do |opt, arg|
  case opt
  when '--help'
    puts <<-EOF
INST_CRED=user:pass what-is-staged.rb [branch_name...]
-h, --help:
   show help
--brief, -b:
   show only top-level branch names that are staged
--all, -a:
   show all unmerged branches
--csv, -c:
   format output as csv
    EOF
    exit
  when '--brief'
    @verbose = false
  when '--all'
    staging_branch_names = @all_unmerged_branches
  when '--csv'
    @csv = true
    @verbose = false
  end
end

staging_branch_names ||= (ARGV || [ "staging" ])

if @verbose
  puts "\nfetching..."
  `git fetch`
  puts "\ncalculating..."
else
  `git fetch >/dev/null 2>&1`
end

@all_unmerged_branches = unmerged_branches("master")

@contained = {}
staging_branch_names.each { |staging_branch_name| summarize(staging_branch_name) }

