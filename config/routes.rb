Rails.application.routes.draw do
  namespace :admin do
    resources :users, :only => [:edit, :update]
  end
  namespace :moderator do
    namespace :post do
      resources :posts, :only => [:delete, :undelete, :expunge, :confirm_delete] do
        member do
          get :confirm_delete
          post :expunge
          post :delete
          post :undelete
          get :confirm_move_favorites
          post :move_favorites
        end
      end
    end
    resources :ip_addrs, :only => [:index, :search] do
      collection do
        get :search
      end
    end
  end
  resources :bans
  resources :comments do
    resource :votes, :controller => "comment_votes", :only => [:create, :destroy]
    collection do
      get :search
    end
    member do
      post :undelete
    end
  end
  resource  :dtext_preview, :only => [:create]
  resources :favorites
  resources :forum_posts do
    member do
      post :undelete
    end
    collection do
      get :search
    end
  end
  resources :forum_topics do
    member do
      post :undelete
      get :new_merge
      post :create_merge
      post :subscribe
      post :unsubscribe
    end
    collection do
      post :mark_all_as_read
    end
    resource :visit, :controller => "forum_topic_visits"
  end
  resources :ip_bans
  resources :mod_actions
  resources :news_updates
  resources :notes do
    collection do
      get :search
    end
    member do
      put :revert
    end
  end
  resources :note_versions, :only => [:index]
  resource :note_previews, :only => [:show]
  resources :pools do
    member do
      put :revert
      post :undelete
    end
    collection do
      get :gallery
    end
    resource :order, :only => [:edit], :controller => "pool_orders"
  end
  resource  :pool_element, :only => [:create, :destroy] do
    collection do
      get :all_select
    end
  end
  resources :pool_versions, :only => [:index] do
    member do
      get :diff
    end
  end
  resources :posts do
    resource :votes, :controller => "post_votes", :only => [:create, :destroy]
    collection do
      get :random
    end
    member do
      put :revert
      put :copy_notes
      get :show_seq
      put :mark_as_translated
    end
  end
  resources :post_versions, :only => [:index, :search] do
    member do
      put :undo
    end
    collection do
      get :search
    end
  end
  resource :related_tag, :only => [:show, :update]
  resources :saved_searches, :except => [:show]
  resource :source, :only => [:show]
  resources :tags do
    collection do
      get :autocomplete
    end
  end
  resources :uploads do
    collection do
      get :batch
      get :image_proxy
    end
  end
  resources :wiki_pages do
    member do
      put :revert
    end
    collection do
      get :search
      get :show_or_new
    end
  end
  resources :wiki_page_versions, :only => [:index, :show, :diff] do
    collection do
      get :diff
    end
  end

  resources :boorus
  resources :dmails, :only => [:new, :create, :index, :show, :destroy] do
    collection do
      post :mark_all_as_read
    end
  end
  resource :session do
    collection do
      get :sign_out
    end
  end
  namespace :maintenance do
    namespace :user do
      resource :email_notification, :only => [:show, :destroy]
      resource :password_reset, :only => [:new, :create, :edit, :update]
      resource :login_reminder, :only => [:new, :create]
      resource :deletion, :only => [:show, :destroy]
      resource :email_change, :only => [:new, :create]
      resource :dmail_filter, :only => [:edit, :update]
    end
  end
  resources :users, constraints: {id: /\d+|me/} do
    resources :memberships
    resource :password, :only => [:edit], :controller => "maintenance/user/passwords"
    collection do
      get :search
      get :custom_style
    end

    member do
      delete :cache
    end
  end
  resource :user_upgrade, :only => [:new, :create, :show]
  resources :user_feedbacks do
    collection do
      get :search
    end
  end
  resources :user_name_change_requests do
    member do
      post :approve
      post :reject
    end
  end
  resources :delayed_jobs, :only => [:index, :destroy] do
    member do
      put :run
      put :retry
      put :cancel
    end
  end

  get "/static/keyboard_shortcuts" => "static#keyboard_shortcuts", :as => "keyboard_shortcuts"
  get "/static/bookmarklet" => "static#bookmarklet", :as => "bookmarklet"
  get "/static/site_map" => "static#site_map", :as => "site_map"
  get "/static/terms_of_service" => "static#terms_of_service", :as => "terms_of_service"
  post "/static/accept_terms_of_service" => "static#accept_terms_of_service", :as => "accept_terms_of_service"
  get "/static/contact" => "static#contact", :as => "contact"
  get "/static/pricing" => "static#pricing"

  root :to => "boorus#new"

  get "*other", :to => "static#not_found"
end
