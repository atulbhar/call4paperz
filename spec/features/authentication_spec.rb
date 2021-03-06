require 'rails_helper'

feature 'Authentications' do
  scenario 'authenticating with some oauth provider' do
    auth = Authentication.new provider: 'github', uid: 'github-uid'
    auth.auth_info = { 'name'  => 'Opa Lhes', 'email' => 'opalhes@example.org' }
    User.find_or_create_with_authentication auth
    sign_in_via_github('github-uid')

    expect(page).to have_content('Welcome Opa Lhes')
  end

  context 'signed in user' do
    let(:auth) { Authentication.new(provider: 'github', uid: 'github-uid') }
    let(:user) { User.find_or_create_with_authentication auth }

    before do
      auth.auth_info = { 'name'  => 'Opa Lhes', 'email' => 'opalhes@example.org' }
      user.save!
      auth.save!
      sign_in_via_github('github-uid')
    end

    scenario 'associating authentication with a signed in user' do
      twitter_uid = 'twitter-123'
      sign_in_via_twitter(twitter_uid)

      authentication_providers = user.reload.authentications.map { |a| a.provider }
      expect(authentication_providers).to include('github', 'twitter')
    end

    scenario 'using a pre-existent authentication different than the current one' do
      Authentication.new(provider: 'twitter', uid: 'twitter-uid-123')
      sign_in_via_twitter('twitter-uid-123')

      authentication_providers = user.reload.authentications.map { |a| a.provider }
      # do not created repeated authentications for the same provider
      expect(authentication_providers).to eq [ 'github', 'twitter' ]
    end
  end

  context 'twitter authentication provider' do
    scenario 'forbiddes account creation, since twitter doesn\'t gives us email' do
      twitter_uid = 'twitter-123'
      sign_in_via_twitter(twitter_uid)

      expect(page).to have_content('Or you can use the following services to login:')
      expect(page).to have_content(I18n.t 'auth.cant_create_twitter')
    end

    scenario 'allow authentication if an associated account exists' do
      twitter_uid = 'twitter-123'
      auth = Authentication.new provider: 'twitter', uid: twitter_uid
      auth.auth_info = { 'name'  => 'Opa Lhes', 'email' => 'opalhes@example.org' }
      User.find_or_create_with_authentication auth
      sign_in_via_twitter(twitter_uid)

      expect(page).to have_content('Welcome Opa Lhes')
    end
  end

  context 'Existent user using different authentications' do
    let(:auth) { Authentication.new(provider: 'github', uid: 'github-uid') }
    let(:user) { User.find_or_create_with_authentication auth }

    before do
      auth.auth_info = { 'name'  => 'Opa Lhes', 'email' => 'opalhes@example.org' }
    end

    scenario 'sign in with new authentication method' do
      sign_in_via_google_oauth2('google-uid-123', 'info' => { 'email' => user.email })
      # do not create new user
      expect(User.count).to eq 1
      providers = user.reload.authentications.map { |auth| auth.provider }
      # add the new authentication to the user
      expect(providers).to eq ['github',  'google_oauth2']
    end
  end
end
