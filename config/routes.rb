# frozen_string_literal: true

KPM::Engine.routes.draw do
  root to: 'nodes_info#index'

  resources :nodes_info, only: [:index]
  resources :plugins, only: [:index]

  scope '/nodes_info' do
    get '/refresh' => 'nodes_info#refresh', :as => 'nodes_info_refresh'
    post '/plugin/install' => 'nodes_info#install_plugin', :as => 'plugin_install'
    post '/plugin/install_from_fs' => 'nodes_info#install_plugin_from_fs', :as => 'plugin_install_from_fs'
    post '/plugin/uninstall' => 'nodes_info#uninstall_plugin', :as => 'plugin_uninstall'
    post '/plugin/start' => 'nodes_info#start_plugin', :as => 'plugin_start'
    post '/plugin/stop' => 'nodes_info#stop_plugin', :as => 'plugin_stop'
    post '/plugin/restart' => 'nodes_info#restart_plugin', :as => 'plugin_restart'
  end
end
