require File.expand_path("shotgun", File.dirname(__FILE__))

Dir["./lib/**/*.rb"].each { |rb| require rb }

Cuba.use Rack::MethodOverride

Cuba.use Rack::Session::Cookie,
  key: ENV["RACK_SESSION_KEY"] || "__insert session key__",
  secret: ENV["RACK_SESSION_SECRET"] || "__insert secret here__"

Cuba.use Rack::Static,
  root: "public",
  urls: ["/js", "/css", "/img"]

Cuba.use OmniAuth::Builder do
  provider :github, ENV["GITHUB_KEY"], ENV["GITHUB_SECRET"], scope: "user,repo"
end

class Cuba
  include Mote::Helpers

  def partial(template, locals = {})
    mote("views/#{template}.mote", locals)
  end

  def view(template, locals = {})
    partial("layout", locals.merge(content: partial(template, locals)))
  end
end

class User < Ohm::Model
  attribute :login
  attribute :name
  attribute :token

  index :login

  def to_hash
    super.merge(login: login, name: name, token: token)
  end

  def repositories
    client.list_repositories
  end

  def issues_for repo_id
    client.list_issues(repo_id)
  end

  protected

  def client
    @client ||= Octokit::Client.new(login: login, oauth_token: token)
  end
end

Cuba.define do
  def current_user
    User[session["User"]]
  end

  def authenticated?
    !current_user.nil?
  end

  def session
    @session ||= env["rack.session"]
  end

  on get, "auth/:provider/callback" do |provider|
    auth = env["omniauth.auth"]

    user = User[auth["uid"].to_i]

    if user.nil?
      user = User.create(id: auth["uid"].to_i)
    end

    user.update(login: auth["info"]["nickname"],
                name: auth["info"]["name"],
                token: auth["credentials"]["token"])

    session["User"] = user.id

    res.redirect "/#{user.login}"
  end

  on get, "logout" do
    session.delete("User")
    res.redirect "/"
  end

  on get, ":login" do |login|
    res.redirect "/" unless authenticated?

    on ":repo/issues" do |repo|
      repo_id = "#{login}/#{repo}"
      res.write view("issues", title: "Issues for #{repo_id}", repo: repo_id, issues: current_user.issues_for(repo_id))
    end

    on default do
      res.write view("user", title: current_user.name)
    end
  end

  on get do
    res.write view("index", title: "Welcome to a new experience using GitHub issues!")
  end
end
