require 'sinatra'
require 'pony'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/inclusion'

set :protection, :origin_whitelist => Proc.new {allowed_domains}
set :environment, :production
set :port, 4569

get '/' do
  halt 401, 'sorry.'
end

get '/healthcheck' do
  'ok'
end

post '/mail' do
  if allowed_domain?
    send_email

    if params[:redirect_to] == 'xhr'# request.xhr? fails for some reason
      response.headers['Access-Control-Allow-Origin'] = '*'
      content_type :json
      halt 200
    else
      redirect_to_specified_or_back
    end
  else
    return redirect back
  end
end

def allowed_domains
  ENV['FORM_MAILER_ALLOWED_DOMAINS'].to_s.split(',')
end

private

def allowed_domain?
  # referrer is blank if going from https -> http
  allowed_domains.include? host_for(request.referrer) || (request.referrer.blank? && redirect_to_is_allowed_domain?)
end

def host_for(uri)
  return nil if uri.blank?

  URI(uri).host
end

def send_email
  Pony.mail({
    to: ENV['FORM_MAILER_TO'],
    from: from,
    subject: subject,
    body: message
  }.merge(smtp_options))
end

def smtp_options
  if ENV['SMTP_ADDRESS']
    {
      via: :smtp,
      via_options: {
        address: ENV['SMTP_ADDRESS'],
        port: ENV['SMTP_PORT'],
        user_name: ENV['SMTP_USERNAME'],
        password: ENV['SMTP_PASSWORD']
      }
    }
  else
    {}
  end
end

def redirect_to_specified_or_back
  if !params[:redirect_to].nil? && redirect_to_is_allowed_domain?
    redirect params[:redirect_to]
  else
    redirect back
  end
end

def redirect_to_is_allowed_domain?
  allowed_domains.include? host_for(params[:redirect_to])
end

def subject
  params[:subject] || "Here's an email!"
end

def from
  "#{from_name} <#{from_email}>"
end

def from_email
  params[:email] || "form-mailer@#{host_for(request.referrer)}"
end

def from_name
  params[:name] || "Sinatra Form Mailer"
end

def message
  params[:message] + "\n\n" + param_list
end

def param_list
  text = ''
  params_without_redirect.each do |k,v|
    unless k.in? [:message, :subject]
      text << "#{k}: #{v}\n"
    end
  end

  text
end

def params_without_redirect
  params.reject{|k,v| %w(redirect_to).include? k.to_s}
end
