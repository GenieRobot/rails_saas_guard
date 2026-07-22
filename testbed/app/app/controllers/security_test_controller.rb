class SecurityTestController < ApplicationController
  skip_forgery_protection

  def ok
    render json: {ok: true, client_ip: request.remote_ip}
  end

  def login
    render json: {ok: true}
  end

  def expensive
    render json: {ok: true}
  end

  def api
    render json: {ok: true}
  end

  def proxy_bucket
    render json: {ok: true, client_ip: request.remote_ip}
  end
end
