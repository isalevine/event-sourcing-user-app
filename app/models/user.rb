class User < ApplicationRecord
  has_many :events, class_name: "Events::User::BaseEvent"
end
