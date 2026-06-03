# frozen_string_literal: true

require 'kpm/client'

module KPM
  class NodesInfoController < EngineController
    helper :all
    include ActionController::Live

    def index
      @installing = params[:i].present?

      @nodes_info = ::KillBillClient::Model::NodesInfo.nodes_info(options_for_klient)

      # For convenience, put pure OSGI bundles at the bottom
      @nodes_info.each do |node_info|
        next if node_info.plugins_info.nil?

        node_info.plugins_info.sort! do |a, b|
          if osgi_bundle?(a) && !osgi_bundle?(b)
            1
          elsif !osgi_bundle?(a) && osgi_bundle?(b)
            -1
          else
            a.plugin_name <=> b.plugin_name
          end
        end
      end

      @kb_host = params[:kb_host] || KillBillClient::API.base_uri
      @last_event_id = params[:last_event_id]

      @tenant_plugin_config = {}
      begin
        raw_tenant_config = ::KillBillClient::Model::Tenant.search_tenant_config('PLUGIN_CONFIG_', options_for_klient)
        @tenant_plugin_config = raw_tenant_config.each_with_object({}) do |e, hsh|
          plugin_name = e.key.gsub('PLUGIN_CONFIG_', '')
          hsh[plugin_name] = e.values[0]
        end
      rescue StandardError => e
        Rails.logger.warn("Unable to fetch tenant plugin config: #{e.inspect}")
      end
    end

    def refresh
      response.headers['Content-Type'] = 'text/event-stream'

      last_event_id_ref = Concurrent::AtomicReference.new(request.headers['Last-Event-Id'] || params[:last_event_id])
      sse = nil
      sse_client = nil
      begin
        # Kaui -> Browser
        sse = ActionController::Live::SSE.new(response.stream, retry: 300, event: 'refresh')

        # Kill Bill -> Kaui
        sse_client = ::Killbill::KPM::KPMClient.stream_osgi_logs(sse, params[:kb_host], last_event_id_ref)

        i = 0
        # We force the browser to reconnect periodically (ensures clients don't block the server shutdown sequence)
        while i < 6 # 30s
          i += 1
          # Keep the thread alive (Kill Bill should send us a heartbeat as well though)
          # Note that we set the id as the last log id, so that we can easily resume
          sse.write('heartbeat', id: last_event_id_ref.get)
          sleep 5
        end
      rescue ActionController::Live::ClientDisconnected
        # ignored
      ensure
        begin
          begin
            sse_client&.close
          rescue StandardError
            # ignored
          end
          sse&.close
        ensure
          # Clear dead DB connections
          # Very lame, but I couldn't do better... Rails will checkout a DB connection
          # whenever a new Thread is spawn and ActiveRecord::Base.clear_active_connections!
          # didn't seem to do the trick: the number of active and dead connections kept growing:
          #     connections = ActiveRecord::Base.connection_pool.instance_eval { @connections }
          #     busy = connections.count { |c| c.in_use? }
          #     dead = connections.count { |c| c.in_use? && !c.owner.alive? }
          ActiveRecord::Base.connection_pool.reap
        end
      end
    end

    def install_plugin
      trigger_node_plugin_command('INSTALL_PLUGIN')
      redirect_to nodes_info_index_path(i: 1)
    end

    def uninstall_plugin
      trigger_node_plugin_command('UNINSTALL_PLUGIN')
      head :ok
    end

    def start_plugin
      trigger_node_plugin_command('START_PLUGIN')
      head :ok
    end

    def stop_plugin
      trigger_node_plugin_command('STOP_PLUGIN')
      head :ok
    end

    def upload_plugin_config
      plugin_name = params[:plugin_name]
      plugin_config = params[:plugin_config]

      if plugin_name.blank?
        flash[:error] = 'Plugin name cannot be blank'
      elsif plugin_config.blank?
        flash[:error] = 'Plugin configuration cannot be blank'
      else
        begin
          user = current_tenant_user
          ::KillBillClient::Model::Tenant.upload_tenant_plugin_config(
            plugin_name,
            plugin_config.gsub(/\r\n?/, "\n"),
            user[:username],
            nil,
            nil,
            options_for_klient
          )
          flash[:notice] = 'Plugin configuration was successfully uploaded'
        rescue StandardError => e
          flash[:error] = "Failed to upload plugin configuration: #{e.message}"
        end
      end

      redirect_to nodes_info_index_path
    end

    def restart_plugin
      trigger_node_plugin_command('RESTART_PLUGIN')
      head :ok
    end

    private

    def trigger_node_plugin_command(command_type, command_properties = [])
      # No need to pass kbVersion -- Kill Bill will figure it out
      command_properties << build_node_command_property('pluginKey', params[:plugin_key])
      command_properties << build_node_command_property('pluginName', params[:plugin_name])
      command_properties << build_node_command_property('pluginVersion', params[:plugin_version])
      command_properties << build_node_command_property('pluginType', params[:plugin_type])
      command_properties << build_node_command_property('pluginUri', params[:plugin_uri])
      command_properties << build_node_command_property('forceDownload', params[:force_download] == '1')

      trigger_node_command(command_type, command_properties)
    end

    def trigger_node_command(command_type, command_properties = [])
      node_command = ::KillBillClient::Model::NodeCommandAttributes.new
      node_command.is_system_command_type = true
      node_command.node_command_type = command_type
      node_command.node_command_properties = command_properties

      # TODO: Can we actually use node_name?
      local_node_only = false

      ::KillBillClient::Model::NodesInfo.trigger_node_command(node_command,
                                                              local_node_only,
                                                              options_for_klient[:username],
                                                              params[:reason],
                                                              params[:comment],
                                                              options_for_klient)
    end

    def build_node_command_property(key, value)
      property = ::KillBillClient::Model::NodeCommandPropertyAttributes.new
      property.key = key
      property.value = value
      property
    end

    def osgi_bundle?(plugin_info)
      plugin_info.version.blank? || plugin_info.plugin_name.starts_with?('org.apache.felix.') || plugin_info.plugin_name.starts_with?('org.kill-bill.billing.killbill-platform-')
    end
  end
end
