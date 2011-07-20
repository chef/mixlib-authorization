# encoding: binary
# ^^ is needed for the email address regex to work properly

require 'active_model'
require 'active_model/validations'

module Opscode
  module Models
    class User
      include ActiveModel::Validations

      # Stolen from CouchRest for maxcompat.
      EmailAddress = begin
        alpha = "a-zA-Z"
        digit = "0-9"
        atext = "[#{alpha}#{digit}\!\#\$\%\&\'\*+\/\=\?\^\_\`\{\|\}\~\-]"
        dot_atom_text = "#{atext}+([.]#{atext}*)*"
        dot_atom = "#{dot_atom_text}"
        qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
        text = "[\\x01-\\x09\\x11\\x12\\x14-\\x7f]"
        quoted_pair = "(\\x5c#{text})"
        qcontent = "(?:#{qtext}|#{quoted_pair})"
        quoted_string = "[\"]#{qcontent}+[\"]"
        atom = "#{atext}+"
        word = "(?:#{atom}|#{quoted_string})"
        obs_local_part = "#{word}([.]#{word})*"
        local_part = "(?:#{dot_atom}|#{quoted_string}|#{obs_local_part})"
        no_ws_ctl = "\\x01-\\x08\\x11\\x12\\x14-\\x1f\\x7f"
        dtext = "[#{no_ws_ctl}\\x21-\\x5a\\x5e-\\x7e]"
        dcontent = "(?:#{dtext}|#{quoted_pair})"
        domain_literal = "\\[#{dcontent}+\\]"
        obs_domain = "#{atom}([.]#{atom})*"
        domain = "(?:#{dot_atom}|#{domain_literal}|#{obs_domain})"
        addr_spec = "#{local_part}\@#{domain}"
        pattern = /^#{addr_spec}$/
      end

      attr_accessor :first_name
      attr_accessor :last_name
      attr_accessor :middle_name
      attr_accessor :display_name
      attr_accessor :email
      attr_accessor :username
      attr_accessor :public_key
      attr_accessor :certificate
      attr_accessor :city
      attr_accessor :country
      attr_accessor :twitter_account
      attr_accessor :image_file_name

      attr_reader :password
      attr_reader :salt

      validates_presence_of :first_name
      validates_presence_of :last_name
      validates_presence_of :display_name
      validates_presence_of :username
      validates_presence_of :email
      validates_presence_of :password
      validates_presence_of :salt

      validates_format_of :username, :with => /^[a-z0-9\-_]+$/
      validates_format_of :email, :with => EmailAddress

      validates_length_of :username, :within => 1..50

      def initialize(params={})
        @first_name = nil
        @last_name = nil
        @middle_name = nil
        @display_name = nil
        @email = nil
        @username = nil
        @public_key = nil
        @certificate = nil
        @city = nil
        @country = nil
        @twitter_account = nil
        @image_file_name = nil
        @password = nil
        @salt = nil
        @persisted = false
      end

      def persisted?
        @persisted
      end

      def persisted!
        @persisted = true
      end

      def to_param
        persisted? ? username : nil
      end

      def to_key
        persisted? ? [username] : nil
      end

    end
  end
end

