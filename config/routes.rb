# frozen_string_literal: true

KPM::Engine.routes.draw do
  root to: 'nodes_info#index'

  resources :nodes_info, only: [:index]
  resources :plugins, only: [:index]

  scope '/nodes_info' do
    match '/refresh' => 'nodes_info#refresh', :via => :get, :as => 'nodes_info_refresh'
    match '/plugin/install' => 'nodes_info#install_plugin', :via => :post, :as => 'plugin_install'
    match '/plugin/install_from_fs' => 'nodes_info#install_plugin_from_fs', :via => :post, :as => 'plugin_install_from_fs'
    match '/plugin/uninstall' => 'nodes_info#uninstall_plugin', :via => :post, :as => 'plugin_uninstall'
    match '/plugin/start' => 'nodes_info#start_plugin', :via => :post, :as => 'plugin_start'
    match '/plugin/stop' => 'nodes_info#stop_plugin', :via => :post, :as => 'plugin_stop'
    match '/plugin/restart' => 'nodes_info#restart_plugin', :via => :post, :as => 'plugin_restart'
    match '/plugin/status' => 'nodes_info#plugin_status', :via => :get, :as => 'plugin_status'
  end
end
