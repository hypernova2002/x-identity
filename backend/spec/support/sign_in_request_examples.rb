# Shared examples for the sign-in requests, which console users (Auth), end users through the API
# (EndUserAuth) and hosted login (HostedLogin) send alike. See SignInFields.
RSpec.shared_examples "an end-user client request" do
  it_behaves_like "a required field", :client_id
  it_behaves_like "a uid field", :client_id
  it_behaves_like "an optional field", :client_secret
  it_behaves_like "a token field", :client_secret
end

RSpec.shared_examples "a challenge response request" do
  it_behaves_like "a required field", :challenge
  it_behaves_like "an enum field", :challenge, values: Auth::Challenges::ALL
  it_behaves_like "a required field", :session
  it_behaves_like "a token field", :session

  it_behaves_like "an optional field", :code
  it_behaves_like "an otp code field", :code
  it_behaves_like "an optional field", :new_password
  it_behaves_like "a password field", :new_password
  it_behaves_like "an optional field", :authentication_id
  it_behaves_like "a token field", :authentication_id
  it_behaves_like "an optional field", :registration_id
  it_behaves_like "a token field", :registration_id
  it_behaves_like "an optional field", :credential
  it_behaves_like "a passkey challenge credential field", :credential
end

RSpec.shared_examples "an email and password request" do
  it_behaves_like "a required field", :email
  it_behaves_like "an email lookup field", :email
  it_behaves_like "a required field", :password
  it_behaves_like "a password field", :password
end

RSpec.shared_examples "an email lookup request" do
  it_behaves_like "a required field", :email
  it_behaves_like "an email lookup field", :email
end

RSpec.shared_examples "a refresh token request" do
  it_behaves_like "a required field", :refresh_token
  it_behaves_like "a token field", :refresh_token
end

RSpec.shared_examples "a challenge session request" do
  it_behaves_like "a required field", :session
  it_behaves_like "a token field", :session
end

RSpec.shared_examples "a passkey sign-in request" do
  it_behaves_like "a required field", :authentication_id
  it_behaves_like "a token field", :authentication_id
  it_behaves_like "a required field", :credential
  it_behaves_like "a passkey assertion field", :credential
end

# Requests that take the email and code, or the token from the email's link.
RSpec.shared_examples "an email code or link request" do
  it_behaves_like "an optional field", :email
  it_behaves_like "an email lookup field", :email
  it_behaves_like "an optional field", :code
  it_behaves_like "an email code field", :code
  it_behaves_like "an optional field", :token
  it_behaves_like "a token field", :token
end
