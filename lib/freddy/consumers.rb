# frozen_string_literal: true

Dir[File.dirname(__FILE__) + '/consumers/*.rb'].each(&method(:require))
