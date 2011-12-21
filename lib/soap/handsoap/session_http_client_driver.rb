# -*- coding: utf-8 -*-
require 'handsoap/http/drivers/abstract_driver'

module Viewpoint
  module EWS
    module SOAP
      class SessionHttpClientDriver < Handsoap::Http::Drivers::AbstractDriver
        @@previous_params = {}
        @@debug_dev = nil

        def self.load!
          require 'httpclient'
        end

        def self.reset
          load!
          @@http_client = HTTPClient.new
          @@http_client.debug_dev = @@debug_dev
          @@previous_params = {}
        end

        def self.debug_dev=(out)
          @@debug_dev = out
          reset
        end

        #The list of parameters that if changed between requests
        #should cause the cached HTTPClient to be invalidated
        def self.request_to_hash(request)
          {
            :username => request.username,
            :password => request.password,
            :trust_ca_file => request.trust_ca_file,
            :client_cert_file => request.client_cert_file,
            :client_cert_key_file => request.client_cert_key_file
          }
        end

        #Preserves the HttpClient across requests so that the TCP session
        #(and SSL session) are kept alive via HTTP Keep-Alive
        def ensure_client(request)

          request_params = self.class.request_to_hash(request)

          #Tests for changes that invalidate the cached HTTPClient
          if(@@previous_params != request_params)
            self.class.reset

            # Set credentials. The driver will negotiate the actual scheme
            if request_params[:username] && request_params[:password]
              domain = request.url.match(/^(http(s?):\/\/[^\/]+\/)/)[1]
              @@http_client.set_auth(domain, request_params[:username], request_params[:password])
            end
            @@http_client.ssl_config.set_trust_ca(request_params[:trust_ca_file]) if request_params[:trust_ca_file]
            @@http_client.ssl_config.set_client_cert_file(request_params[:client_cert_file],request_params[:client_cert_key_file]) if request_params[:client_cert_file] and request_params[:client_cert_key_file]
          end

          @@previous_params = request_params
          nil
        end

        def send_http_request(request)
          ensure_client(request)
          # pack headers
          headers = request.headers.inject([]) do |arr, (k,v)|
            arr + v.map {|x| [k,x] }
          end
          response = @@http_client.request(request.http_method, request.url, nil, request.body, headers)
          response_headers = response.header.all.inject({}) do |h, (k, v)|
            k.downcase!
            if h[k].nil?
              h[k] = [v]
            else
              h[k] << v
            end
            h
          end
          parse_http_part(response_headers, response.content, response.status, response.contenttype)
        end
      end
    end
  end
end
