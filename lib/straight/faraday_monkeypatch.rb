Faraday::SSLOptions = Faraday::Options.new(*(Faraday::SSLOptions.members | [:verify_callback])) do

  def verify?
    verify != false
  end

  def disable?
    !verify?
  end
end

Faraday::ConnectionOptions.options(ssl: Faraday::SSLOptions)

Faraday::Adapter::NetHttp.class_exec do

  alias_method :orig_configure_ssl, :configure_ssl

  def configure_ssl(http, ssl)
    http.verify_callback = ssl[:verify_callback] if ssl[:verify_callback]
    orig_configure_ssl(http, ssl)
  end
end
