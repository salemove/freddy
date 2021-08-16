# frozen_string_literal: true

Dir["#{File.dirname(__FILE__)}/consumers/*.rb"].sort.each(&method(:require))
