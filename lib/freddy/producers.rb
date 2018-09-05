# frozen_string_literal: true

Dir[File.dirname(__FILE__) + '/producers/*.rb'].each(&method(:require))
