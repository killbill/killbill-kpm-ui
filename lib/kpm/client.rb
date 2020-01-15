# frozen_string_literal: true

require 'ld-eventsource'

module Killbill
  module KPM
    class KPMClient < KillBillClient::Model::Resource
      KILLBILL_KPM_PREFIX = '/plugins/killbill-kpm'
      KILLBILL_OSGI_LOGGER_PREFIX = '/plugins/killbill-osgi-logger'

      class << self
        def get_available_plugins(kb_version_maybe_snapshot, latest = true, options = {})
          # Mostly useful for Kill Bill developers: get the latest version before the current snapshot
          # (we rarely deploy SNAPSHOT jars)
          captures = kb_version_maybe_snapshot.scan(/0.(\d+)(\.)?(\d+)?(-SNAPSHOT)?/)
          # [["20", ".", "1", "-SNAPSHOT"]]
          if !captures.nil? && !captures.first.nil? && !captures.first[3].nil?
            if captures.first[2].to_i > 0
              kb_version = '0.' + captures.first[0] + '.' + (captures.first[2].to_i - 1).to_s
            else
              kb_version = '0.' + (captures.first[0].to_i - 1).to_s + '.0'
            end
          else
            kb_version = kb_version_maybe_snapshot
          end

          path = "#{KILLBILL_KPM_PREFIX}/plugins"
          response = KillBillClient::API.get path, { :kbVersion => kb_version, :latest => latest }, options
          JSON.parse(response.body)
        end

        def stream_osgi_logs(writer, host, last_event_id_ref)
          url = host
          url = "http://#{url}" unless url.starts_with?('http:')
          SSE::Client.new(url + KILLBILL_OSGI_LOGGER_PREFIX, :last_event_id => last_event_id_ref.get, :logger => Rails.logger) do |client|
            client.on_event do |event|
              writer.write(event.data, :id => event.id)
              last_event_id_ref.set(event.id)
            end
          end
        end

        def install_plugin(key, version, type, filename, plugin, options = {})
          path = "#{KILLBILL_KPM_PREFIX}/plugins"
          KillBillClient::API.post path, plugin, { :key => key, :version => version, :type => type, :filename => filename }, options.merge(:content_type => 'application/octet-stream')
        end
      end
    end
  end
end
