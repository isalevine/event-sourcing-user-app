class Events::User::BaseEvent < Events::BaseEvent
  self.table_name = "user_events"

  belongs_to :user, class_name: "::User"
end