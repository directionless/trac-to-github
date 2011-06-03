require 'yaml'
require 'sqlite3'
require 'Octokit'
require 'pp'

class TracMigrate

  public

  def initialize(options={})
    @options = options
    gitconfig = read_gitconfig
    @options[:gh_login] = gitconfig[:github][:user] unless @options[:login]
    @options[:gh_token] = gitconfig[:github][:token] unless @options[:token]
    @options[:config_files].map {|cf| cf if ::File.file? cf}.compact.each do |cfile|
      @options.merge!(::File.open(cfile) { |yf| symbolize_keys(::YAML::load_file(yf)) })
    end

    init_trac
    init_github
  end

  def go
    pp @options
  end

  def migrate_tickets
    ticket_comments_q=@trac_db.prepare("select * from ticket_change where field=\"comment\" and ticket=?")

    @trac_db.execute( "select * from ticket" ) do |trac_ticket|
      #p trac_ticket['status']
      title_key = ":trac-#{trac_ticket['id']}:"
      title = "#{trac_ticket['summary']} #{title_key}"
      puts "Working On: #{title_key} #{trac_ticket['summary']}"
      existing_ticket = @gh_issues.select {|i| i["title"].include?(title_key) }

      case existing_ticket.length
      when 0
        debug("#{title_key} doesn't exist")
        ticket_id = gh_create_issue(title, trac_ticket)
      when 1
        debug("#{title_key} exists")
        ticket_id = existing_ticket.first["number"]
      else
        pp existing_ticket
        raise "Too many matches for key #{title_key}"
      end

      gh_comments = @github.issue_comments(@gh_repo, ticket_id)


      ticket_comments_q.execute(trac_ticket['id']).each do |trac_ticket_comment|
        comment_key="#{trac_ticket_comment['ticket']}.#{trac_ticket_comment['time']}.#{trac_ticket_comment['field']}"
        if gh_comments.select{ |c| c['body'].match(comment_key) }.length == 0
          debug("#{title_key} has a new comment")
          @github.add_comment(@gh_repo, 
                              ticket_id, 
                              ["On #{Time.at(trac_ticket_comment['time'])} #{trac_ticket_comment['author']} said:",
                               trac_ticket_comment['newvalue'],
                               "------",
                               "(trac id #{comment_key})",
                              ].join("\n\n"),
                            )
          sleep @options[:sleep]
        else
          debug("#{title_key} has a comment I've seen already")
        end
      end
    end
  end


  private

  def debug(message)
    puts message
  end

  def gh_create_issue(title, trac_ticket)
    trac_id = trac_ticket['id']

    @gh_issues <<  @github.create_issue(@gh_repo, 
                                        title, 
                                        "Autocreated from trac ticket #{trac_id} #{@options[:trac_url]}/ticket/#{trac_id}")
    ticket_id = @gh_issues.last["number"]
    @github.add_comment(@gh_repo, ticket_id, trac_ticket['description'])
    @github.add_label(@gh_repo, "trac-import", ticket_id)
    @github.add_label(@gh_repo, @options[:priority_map][trac_ticket['priority'].to_sym], ticket_id) 
    @github.close_issue(@gh_repo, ticket_id) if @options[:status_map][trac_ticket['status'].to_sym].match("closed")

    # 5 actions, so sleep * 5.
    sleep @options[:sleep] * 5

    return ticket_id
  end

  def init_trac
    @trac_db = SQLite3::Database.new(@options[:trac_db])
    @trac_db.results_as_hash = true
  end

  def init_github
    @github = Octokit::Client.new(:login => @options[:gh_login], 
                                  :token => @options[:gh_token])
    @gh_repo = Octokit::Repository.new("#{@options[:gh_user]}/#{@options[:gh_repository]}")

    # Find all existing tickets. We're basically trading memory for
    # fewer GH searches later.
    @gh_issues = @github.list_issues(@gh_repo, "open")
    @gh_issues << @github.list_issues(@gh_repo, "closed")
    @gh_issues.flatten!
  end

  def read_gitconfig
    config = {}
    group = nil
    File.foreach("#{ENV['HOME']}/.gitconfig") do |line|
      line.strip!
      if line[0] != ?# && line =~ /\S/
        if line =~ /^\[(.*)\]$/
          group = $1.to_sym
          config[group] ||= {}
        else
          key, value = line.split("=").map { |v| v.strip }
          config[group][key.to_sym] = value
        end
      end
    end
    return config
  end

  
  def symbolize_keys(hash)  
    hash.inject({}){ |result, (key, value)|  
      new_key = case key  
                when String then key.to_sym  
                else key  
                end  
      new_value = case value  
                  when Hash then symbolize_keys(value)  
                  else value  
                  end  
      result[new_key] = new_value  
      result
    }
  end


end
