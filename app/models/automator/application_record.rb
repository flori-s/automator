# frozen_string_literal: true

module Automator
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
