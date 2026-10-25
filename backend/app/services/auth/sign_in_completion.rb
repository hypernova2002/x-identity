module Auth
  # Who signed in, and how, when the sign-in ends without tokens: hosted login turns this into a
  # browser session and an authorization code instead.
  SignInCompletion = Data.define(:user, :amr, :authenticated_at)
end
