module Users
  # How many console users an account has, and how many are admins or owners.
  class Stats
    # @param account [Account]
    # @param include_invitations [Boolean] also count pending invitations, which only account admins can see
    def initialize(account, include_invitations:)
      @account = account
      @include_invitations = include_invitations
    end

    # @return [Hash{Symbol => Integer, nil}] total, admins and pending_invitations (nil unless included)
    def call
      total, admins = @account.users.pick(Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE role IN ('owner', 'admin'))"))
      { total: total, admins: admins, pending_invitations: @include_invitations ? @account.invitations.pending.count : nil }
    end
  end
end
