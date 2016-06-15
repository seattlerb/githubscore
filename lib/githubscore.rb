require "octokit"

Octokit.auto_paginate = true

class Githubscore
  VERSION = "1.0.0"

  NOW = Time.now
  SECS_PER_WEEK = 86_400 * 7

  def self.run args
    self.new.run args
  end

  def run args
    repos = process_args args
    stats = process_repos repos

    sorted = stats.sort_by { |_, bc, _, ba, pc, _, pa, tot| [-tot, -bc-pc] }

    total = 0

    sorted.each do |data|
      total += data[-1]
      puts "%-35s = %3d %10s %3dw | %3d %10s %3dw | %4dw" % data
    end

    puts
    puts "total = %d" % total
  end

  def process_args args
    args << client.user.login if args.empty?

    repos = args.flat_map { |name|
      case name
      when /^\w+$/ then
        client.repos(name, :type => "owner")
      when /\// then
        client.repo(name)
      else
        abort "Unhandled arg: #{name.inspect}"
      end
    }.uniq

    repos.sort_by { |h|
      -h[:stargazers_count] - h[:watchers_count] - h[:forks_count]
    }.map { |h| h[:full_name] }
  end

  def process_repos repos
    fmt = "\r%4d/%4d"
    max = repos.size

    done = false
    stats = repos.each_with_index.map { |repo, i|
      next if done

      $stderr.print fmt % [i, max]

      issues = begin
                 client.list_issues repo
               rescue Interrupt
                 done = true
                 next
               end

      next if issues.empty?
      prs, bugs = issues.partition { |h| h[:pull_request] }

      [
       repo,
       bugs.count, oldest(bugs), avg_weeks(bugs),
       prs.count,  oldest(prs),  avg_weeks(prs),
       tot_weeks(issues),
      ]
    }.compact

    $stderr.print "\n\n"

    stats
  end

  def avg_weeks ary
    return 0 if ary.empty?
    tot_weeks(ary) / ary.size
  end

  def tot_weeks ary
    return 0 if ary.empty?
    ary.map { |h| NOW - h[:created_at] }.inject(&:+) / SECS_PER_WEEK
  end

  def oldest ary
    old = ary.map { |h| h[:created_at] }.min
    old && old.iso8601[0..9] || "n/a"
  end

  def git_param name, default = nil
    param = `git config github.#{name}`.chomp
    param.empty? ? default : param
  end

  def client
    @client ||=
      begin
        endpoints = {}
        endpoints[:api] = git_param(:api)
        endpoints[:web] = git_param(:web)

        auth = {
                :name     => git_param(:name),
                :user     => git_param(:user),
                :oauth    => git_param("oauth-token"),
               }

        unless auth[:user] && auth[:oauth]
          raise "Missing authentication parameters."
        end

        auth[:name] ||= auth[:user]

        Octokit::Client.new :access_token => auth[:oauth]
      end
  end
end
