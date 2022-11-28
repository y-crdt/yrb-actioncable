# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yrb::Actioncable::Engine => "/yrb-actioncable"
end
