# This README is the tutorial to create an Event Sourcing system in Ruby on Rails.
The article can be found on Dev.to here:
[https://dev.to/isalevine/building-an-event-sourcing-system-in-rails-part-2-building-our-event-pattern-from-scratch-168p-temp-slug-1608448?preview=2640d0e9af2c0b95d6c79592e33429c8604aa7b6b44734ca55e33ca5c19942669fe6b9913cc71b333787bee60dca1f7993d03a9a2e78455a554b3d3c](https://dev.to/isalevine/building-an-event-sourcing-system-in-rails-part-2-building-our-event-pattern-from-scratch-168p-temp-slug-1608448?preview=2640d0e9af2c0b95d6c79592e33429c8604aa7b6b44734ca55e33ca5c19942669fe6b9913cc71b333787bee60dca1f7993d03a9a2e78455a554b3d3c)

# To Recap: What is Event Sourcing?

Event Sourcing is a system design pattern that emphasizes recording changes to data via immutable events.

In other words: *every time your data changes*, you save an event to your database with the details. 

**Those events never change or go away.** That way, you have a permanent, unchanging history of how your data reached its current state!


# What this article covers
We will primarily be working off of [Kickstarter's event sourcing example.](https://kickstarter.engineering/event-sourcing-made-simple-4a2625113224)

To create our Event pattern, we’ll take the following steps:
-   Get our Rails app up and running
	-  	`User` model and controller
	-   PostgreSQL for our database
-   Set up our environment to test our Events
	-   Postico to inspect our database
	-   Insomnia for REST client
-   Add our Events pattern
	-   What is an Event, and what Event data will we store in the database?
	-   The BaseEvent that other Event classes will inherit from
	-   `Events::User::Created`
	-   `Events::User::Destroyed`


# Getting our Rails app up and running

## Let’s go ahead and create our new Rails app
We’ll set the database to PostgreSQL with `--database=postgresql` and skip tests with `--skip-test`, as we will be adding RSpec manually later.
```ruby
rails new event-sourcing-user-app --database=postgresql --skip-test
```

## Let’s add our `User` model
Our `User` model will have several fields:
-   `name` String,
-   `email` String,
-   `password_digest` String (for bcrypt)
-   `deleted` Boolean (remember, part of event sourcing is that we **never delete data**—instead, we will flag certain Users as _being_ deleted, and scope our queries appropriately)
	-   this field also needs to be `null: false`, and be set to `default: false`

We’ll start this with Rails one-liner:
```ruby
rails g model User name email password_digest deleted:boolean
```

And inside the new migration, tweak the `t.boolean :deleted` to be `null: false` and `default: false`:
```ruby
# db/migrate/20200502025357_create_users.rb

class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.boolean :deleted, null: false, default: false

      t.timestamps
    end
  end
end
```

## Add a `User` controller and routes
Our User controller needs to have two actions, a `create` and `destroy` action, to handle the Events we want to make.

Let’s create our controller manually, since we don’t need any views to be generated. In `app/controllers`, create a `users_controller` and add `def create` and `def destroy` actions:
```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def create
  end

  def destroy
  end
end
```

Since we are not implementing auth yet, we’ll also add a `skip_before_action` hook to make testing our code easier:
```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :destroy]

  def create
  end

  def destroy
  end
end
```

Next, let’s manually add a POST and DELETE route that will go to the `create` and `destroy` actions in our controller:
```ruby
# config/routes.rb

Rails.application.routes.draw do
  post 'users/create', to: 'users#create'
  delete 'users/destroy', to: 'users#destroy'
end
```

Run `rails routes` in your console to see that the routes are set up correctly:
```
[13:29:44] (master) event-sourcing-user-app
// ♥ rails routes                         
Prefix           Verb     URI Pattern                 Controller#Action
users_create     POST     /users/create(.:format)     users#create
users_destroy    DELETE   /users/destroy(.:format)    users#destroy
```

## Run database migrations
Now, let’s create our databases and run our migrations in the usual two-step:
```ruby
rails db:create
rails db:migrate
```


# Setting up our environment to test our Events

## Set up Postico to view our PostgreSQL database
If you’re not familiar with [Postico](https://eggerapps.at/postico/), it’s a a database management tool and viewer with a great free trial. 

Download and install from their website, and open it up. Go ahead and hit `Connect` to in the `localhost` using its default settings:

![Postico's main page](https://dev-to-uploads.s3.amazonaws.com/i/3e01npyfqoi9iwb84i2t.png)

From here, click the `localhost` button at the top to go to a list of available databases:

![Postico landing page inside localhost](https://dev-to-uploads.s3.amazonaws.com/i/ckp52em08tqocdr1yno6.png)

And now, we should be able to select our development database:

![Postico page listing available databases](https://dev-to-uploads.s3.amazonaws.com/i/t7cm9r4lp4el3va6mms3.png)

Select our `users` table:

![Postico page inside development database, showing users table](https://dev-to-uploads.s3.amazonaws.com/i/sj9trljc4a6wubgx7fcj.png)

And, hurray—there’s our User model, with it’s four fields:

![Postico users table](https://dev-to-uploads.s3.amazonaws.com/i/ge2z2vqt53m56cgxbvi0.png)


## Set up Insomnia to send HTTP requests
Likewise, if you’re not familiar with [Insomnia](https://insomnia.rest/), it’s a tool for sending HTTP requests to test RESTful APIs. We’ll be using **Insomnia Core**.

Download, install, and open it up:

![Insomnia Core main page](https://dev-to-uploads.s3.amazonaws.com/i/7fku2239n0kymgfgl0lv.png)

Create a folder for our project, `event-sourcing-user-app`:

![Insomnia showing new project folder](https://dev-to-uploads.s3.amazonaws.com/i/388jrxxujj7n5e52fs06.png)

Let’s create our first request. We’ll make it a POST request, which we’ll user for a **create User** route:

![Insomnia showing new request being set to POST](https://dev-to-uploads.s3.amazonaws.com/i/khu76n08h5ubparkc8yk.png)

And lastly, we’ll set the target URL to `localhost:3000/users/create` for testing later:

![Insomnia showing target URL for Create User request](https://dev-to-uploads.s3.amazonaws.com/i/uu41v34shfies4g4dnju.png)

Yay, now Insomnia’s ready to go! We’ll just need to fill out the body of our request with a hash once we have our Events created.

## Testing the `create` action with `byebug` and Insomnia

You can test out the routes by adding a `byebug` to the controller action:
```ruby
# app/controllers/users_controller.rb

def create
  byebug
end
```

Fire up `rails s`, and send a POST request to `localhost:3000/users/create` in Insomnia. In your console, you will see `byebug` session:

![screenshot showing Insomnia request, and console inside a byebug session](https://dev-to-uploads.s3.amazonaws.com/i/6aywcx4o8j104jdyshq1.png)

Great, we can see our route working as expected!

**Now, we’re ready to build our event pattern!**



# What is an Event?
In our event sourcing system, each Event will be **a Rails model that stores information about changes to our data**. 

Our goal is to build two events:
-   `Events::User::Created` — this will record:
	-   `payload`: a hash containing the `name`, `email`, and `password` params to create the User
	-   `user_id`: the created User’s `id`, used as a `belongs_to` relationship
	-   `event_type`: a String to show that this `user_event` is the `”Created”` type
	-   timestamps
-   `Events::User::Destroyed` — this will record:
	-   `payload`: a hash containing the `id` for the User to be flagged as deleted
	-   `user_id`: the target User’s `id`, used as a `belongs_to` relationship
	-   `event_type`: a String to show that this `user_event` is the `”Destroyed”` type
	-   timestamps

When our Rails app creates or destroys a User, this will also trigger creating a new Event.

These events will be saved to our database, and will be **immutable** to serve as a permanent log of changes.

Since we might end up having _a lot_ of User-related events, we’re also including the `event_type` field on our User events so we can store them all in one `user_events` table—and easily add add more later!


# The `Events::BaseEvent`
Our events will be built through inheritance. At the top of the chain, we will define `Events::BaseEvent` where a lot of the event functionality will live.

Since all of our events will be Rails models, go ahead and create a new `/events` directory inside `app/models`.

Now, we can create our BaseEvent:
```ruby
# app/models/events/base_event.rb

class Events::BaseEvent < ActiveRecord::Base
end
```

## `abstract_class`
Since the BaseEvent only exists for inheritance, we can make it an `abstract_class` so Rails knows not to try to load any records for it:
```ruby
# app/models/events/base_event.rb

class Events::BaseEvent < ActiveRecord::Base
  self.abstract_class = true
end
```

## `apply(aggregate)` and `apply_and_persist`
Each event will have to define its own `apply` method. This method will accept an `aggregate`—another model, in our case a User—and update its attributes.
_(The term `aggregate` comes from the Kickstarter event sourcing system, and [you can read more about it here](https://kickstarter.engineering/event-sourcing-made-simple-4a2625113224). Basically, `aggregates` are models that receive changes via `events`.)_

On BaseEvent, we’ll simply raise a `NotImplementedError`. This will enforce us having to define it explicitly on each event, thus overriding the error via inheritance.

The BaseEvent will also have a `before_create` hook that calls `apply_and_persist`. This will call `apply`, then `save!` the update to the database. 
_(It will also set the event’s `aggregate_id`, specifically for Created events where the `id` doesn’t exist until after `save!` is called.)_

Let’s look at the code we’ll add:

```ruby
# app/models/events/base_event.rb

before_create :apply_and_persist

def apply(aggregate)
  raise NotImplementedError
end

private def apply_and_persist
  # Lock the database row! (OK because we're in an ActiveRecord callback chain transaction)
  aggregate.lock! if aggregate.persisted?

  # Apply!
  self.aggregate = apply(aggregate)

  #Persist!
  aggregate.save!

  # Update aggregate_id with id from newly created User
  self.aggregate_id = aggregate.id if aggregate_id.nil?
end
```



## `after_initialize` and `event_type`
No matter what kind of event we instantiate, there are a couple attributes we want to set right away:
-   `event_type` — every Event needs to be explicitly categorized for when it’s stored in the `user_events` table as a `BaseEvent` record
-   `payload` — since we always expect `payload` to be accessible as a hash (and stored in our PostgreSQL database as JSON), we’ll add a `||` clause to set it to `{}` if the event accepts no params

So, we’ll add an `after_initialize` hook to set those attributes:
```ruby
# app/models/events/base_event.rb

after_initialize do
  self.event_type = event_type
  self.payload ||= {}
end

def event_type
  self.attributes["event_type"] || self.class.to_s.split("::").last
end
```

Above, we define `event_type` to quickly access its own type via `attributes` if loaded from our database—or upon first creation, deducing its type from the Event class’s name.


## `self.payload_attributes(*attributes)`
In each Event class we create, we want the option to define possible `payload_attributes` we want to record.

On BaseEvent, `self.payload_attributes` will create the getters and setters for our payload fields:
```ruby
# app/models/events/base_event.rb

def self.payload_attributes(*attributes)
  @payload_attributes ||= []

  attributes.map(&:to_s).each do |attribute|
    @payload_attributes << attribute unless @payload_attributes.include?(attribute)

    define_method attribute do
      self.payload ||= {}
      self.payload[attribute]
    end

    define_method "#{attribute}=" do |argument|
      self.payload ||= {}
      self.payload[attribute] = argument
    end
  end

  @payload_attributes
end
```

Ultimately, this will let us define attributes like this at the top of each new Event class: `payload_attributes :name, :email, :password`


## `find_or_build_aggregate`
We want our events to be aware of their aggregates—in our case, the target User—and be able to either look it up, or create a new one.

We’ll add a `before_validation` hook (which gets called _really early_ in the `.create` lifecycle) which will either look up or create the aggregate, based on whether an `id` is present in the event’s params:

```ruby
# app/models/events/base_event.rb

before_validation :find_or_build_aggregate

private def find_or_build_aggregate
  self.aggregate = find_aggregate if aggregate_id.present?
  self.aggregate = build_aggregate if self.aggregate.nil?
end

def find_aggregate
  klass = aggregate_name.to_s.classify.constantize
  klass.find(aggregate_id)
end

def build_aggregate
  public_send "build_#{aggregate_name}"
end
```

Let’s see the code:

## `aggregate` setters, getters, and get-its-namers
To round out our events’ functionality, we’ll want some setters and getters—as well as methods to easily return its type or class name:
-   `aggregate=(model)` and `aggregate` will set and get the User our event targets
-   `aggregate_id=(id)` and `aggregate_id` will map to the `user_id` field on our `user_events` table
-   `self.aggregate_name` gives the Event class awareness of its `belongs_to` relationship’s target class (`#=> User`)
-   `delegate :aggregate_name, to: :class` will return a Symbol of the aggregate’s class name (`#=> :user`)
-   `def event_klass` will convert our Event class’s `::BaseEvent` namespace into its appropriate event type (`#=> Events::User::Created`)

```ruby
# app/models/events/base_event.rb

def aggregate=(model)
  public_send "#{aggregate_name}=", model
end

# Return the aggregate record that the event will apply to
def aggregate
  public_send aggregate_name
end

def aggregate_id=(id)
  public_send "#{aggregate_name}_id=", id
end

def aggregate_id
  public_send "#{aggregate_name}_id"
end

def self.aggregate_name
  inferred_aggregate = reflect_on_all_associations(:belongs_to).first
  raise "Events must belong to an aggregate" if inferred_aggregate.nil?
  inferred_aggregate.name
end

delegate :aggregate_name, to: :class

def event_klass
  klass = self.class.to_s.split("::")
  klass[-1] = event_type
  klass.join('::').constantize
end
```

## Okay, let’s see the whole `Events::BaseEvent`!
```ruby
# app/models/events/base_event.rb

# Kickstarter code reference:
# https://github.com/pcreux/event-sourcing-rails-todo-app-demo/blob/master/app/models/lib/base_event.rb

class Events::BaseEvent < ActiveRecord::Base
  before_validation :find_or_build_aggregate
  before_create :apply_and_persist

  self.abstract_class = true

  def apply(aggregate)
    raise NotImplementedError
  end

  after_initialize do
    self.event_type = event_type
    self.payload ||= {}
  end

  def self.payload_attributes(*attributes)
    @payload_attributes ||= []

    attributes.map(&:to_s).each do |attribute|
      @payload_attributes << attribute unless @payload_attributes.include?(attribute)

      define_method attribute do
        self.payload ||= {}
        self.payload[attribute]
      end

      define_method "#{attribute}=" do |argument|
        self.payload ||= {}
        self.payload[attribute] = argument
      end
    end

    @payload_attributes
  end

  private def find_or_build_aggregate
    self.aggregate = find_aggregate if aggregate_id.present?
    self.aggregate = build_aggregate if self.aggregate.nil?
  end

  def find_aggregate
    klass = aggregate_name.to_s.classify.constantize
    klass.find(aggregate_id)
  end

  def build_aggregate
    public_send "build_#{aggregate_name}"
  end

  private def apply_and_persist
    # Lock the database row! (OK because we're in an ActiveRecord callback chain transaction)
    aggregate.lock! if aggregate.persisted?

    # Apply!
    self.aggregate = apply(aggregate)

    #Persist!
    aggregate.save!
    self.aggregate_id = aggregate.id if aggregate_id.nil?
  end

  def aggregate=(model)
    public_send "#{aggregate_name}=", model
  end

  def aggregate
    public_send aggregate_name
  end

  def aggregate_id=(id)
    public_send "#{aggregate_name}_id=", id
  end

  def aggregate_id
    public_send "#{aggregate_name}_id"
  end

  def self.aggregate_name
    inferred_aggregate = reflect_on_all_associations(:belongs_to).first
    raise "Events must belong to an aggregate" if inferred_aggregate.nil?
    inferred_aggregate.name
  end

  delegate :aggregate_name, to: :class

  def event_type
    self.attributes["event_type"] || self.class.to_s.split("::").last
  end

  def event_klass
    klass = self.class.to_s.split("::")
    klass[-1] = event_type
    klass.join('::').constantize
  end

end
```


# The `user_events` table, and the `Events::User::BaseEvent`
We previously mentioned that we will be storing multiple types of User-related events in a single `user_events` table. 

To accomplish this and allow us to easily add more events later, we will create an `Events::User::BaseEvent` which will tell all events in the `Events::User::` namespace to save to the `user_events` table. We will also define a `belongs_to` relationship with a User here.

## `user_events` table
Let’s go ahead and create our `user_events` table in our database.

[Kickstarter’s event sourcing example](https://kickstarter.engineering/event-sourcing-made-simple-4a2625113224) describes that each `aggregate` (User) has an event table (`user_events`). These event tables will have a similar schema—we will tweak them slightly to match our verbiage:
> Each Aggregate (ex: subscriptions) has an Event table associated to it (ex: subscription_events).
> …
> All events related to an aggregate are stored in the same table. All events tables have a similar schema:
> `id, aggregate_id, type, data (json), metadata (json), created_at`

A few things we’ll tweak for our code:
-   `aggregate_id` will be replaced by `user_id`
-   `type` will be replaced by `event_type` (just to be more explicit)
-   `data` will be replaced by `payload`, and will still be type JSON
-   `metadata` will not be included at this time, since our events are relatively simple
-   `created_at` will not be included, since we will simply rely on ActiveRecord’s default timestamps

We will create our `user_events` table with a Rails migration:
```ruby
rails g migration CreateUserEvents
```

This will create our migration with a `create_table` block set up for us:
```ruby
# db/migrate/20200502192018_create_user_events.rb

class CreateUserEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :user_events do |t|
    end
  end
end
```

We want to add four fields:
-   a `belongs_to` relationship to a `:user`
-   an `event_type` String
-   a `payload` JSON
-   timestamps

```ruby
# db/migrate/20200502192018_create_user_events.rb

class CreateUserEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :user_events do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :event_type
      t.json :payload

      t.timestamps
    end
  end
end
```

Run the migration:
```ruby
rails db:migrate
```

And open up Postico to check out the new `user_events` table:

![Postico page showing the user_events table selected](https://dev-to-uploads.s3.amazonaws.com/i/q90r3lfnvvnir8dgh1sa.png)

Our table and fields are ready to go!

![Postico page showing user_events table fields](https://dev-to-uploads.s3.amazonaws.com/i/wrmi6ouzhth65g4mte3p.png)


## `Events::User::BaseEvent`
Inside our `app/models/events` directory, create a new `user` directory.

Inside that directory, create a new file `base_event.rb`. This gives us the namespacing to create this class:
```ruby
# app/models/events/user/base_event.rb

class Events::User::BaseEvent < Events::BaseEvent
  self.table_name = "user_events"
end
```

With `self.table_name = “user_events”`, any new Event class we create that inherits from `Events::User::BaseEvent` will automatically be saved and retrieved from the `user_events` table!


## `belongs_to :user` and `has_many :events`
Since all our User-related events target a User, it makes sense to create a `has_many / belongs_to` relationship between Users and Events in the `Events::User::` namespace.

Since we’re deep in a namespace that uses the name `User`, to tell Rails to look for the regular top-level `User` model, we need to add `::` before our classnames. This tells our `has_many` and `belongs_to` relationships to look outside the current namespace.

Let’s update our `Events::User::BaseEvent` and `User` classes with the relationships:
```ruby
# app/models/events/user/base_event.rb

class Events::User::BaseEvent < Events::BaseEvent
  self.table_name = "user_events"

  belongs_to :user, class_name: "::User"
end


# app/models/user.rb

class User < ApplicationRecord
  has_many :events, class_name: "Events::User::BaseEvent" 
end
```

Great! Now, when we load a User into a `user` variable, we can call `user.events` to load all related events from the `user_events` table.

**We’re now ready to create some real, _usable_ Events!**


# Creating a new User with `Events::User::Created`
With our BaseEvent pattern in place, we can now build our first event!

`Events::User::Created` will record the params used to create a User, as well as the new User’s id, and the event’s timestamp.

## Build the `Events::User::Created` class
In `app/models/events/user`, make a new `created.rb` file. Our class will inherit from `Events::User::BaseEvent` in the same directory:
```ruby
# app/models/events/user/created.rb

class Events::User::Created < Events::User::BaseEvent
end
```

As we defined in the top-level `Events::BaseEvent`, we must define an `apply` method that will take a User instance as its `aggregate` argument:
```ruby
# app/models/events/user/created.rb

class Events::User::Created < Events::User::BaseEvent
  def apply(user)
  end
end
```

Since we know creating a User requires params with a `name`, `email`, and `password`, we can also add them as a list of symbols to `payload_attributes` to create our getters and setters:
```ruby
# app/models/events/user/created.rb

class Events::User::Created < Events::User::BaseEvent
  payload_attributes :name, :email, :password

  def apply(user)
  end
end
```

## Add logic to the `apply` method
The logic in the event’s `apply` method is where the event’s power lies. It:
-   takes in a User instance
-   applies the changes to the User instance, supplied by `payload_attributes`
-   returns the mutated User instance => **this is where the top-level BaseEvent receives back the User instance, and calls `save!` to persist the changes in the database!**

Thanks to the list of attributes passed to `payload_attributes`, we can simply call the attributes inside our `apply` method to update the User instance:
```ruby
# app/models/events/user/created.rb

payload_attributes :name, :email, :password

def apply(user)
  user.name = name
  user.email = email
  user.password_digest = password

  user
end
```

Perfect! Now, all we need to do is tell Insomnia to pass params that contain `name`, `email`, and `password` Strings, and our event will map them to the User model’s `name`, `email`, and `password_digest` fields. 
_(Remember: `password_digest` is related to `bcrypt` functionality, which we will explore in another article.)_


## Update our controller to create an Event and use strong params
Back in our `users_controller`, we need to update two things:
-   the `create` action needs to call `Events::User::Created.create(payload: user_params)`
-   add strong params to protect the `user_params` we will pass to `.create(payload: user_params)`

For the strong params, we will require the `user_params` to have `name`, `email`, and `password` nested inside a `user` key:
```ruby
# app/controllers/users_controller.rb

private def user_params
  params.require(:user).permit(:name, :email, :password)
end
```

Now, we can safely pass `user_params` to `Events::User::Created.create(payload: user_params)` in the `create` action:
```ruby
# app/controllers/users_controller.rb

def create
  Events::User::Created.create(payload: user_params)
end

private def user_params
  params.require(:user).permit(:name, :email, :password)
end
```

## Let’s test our event with Insomnia and Postico!
If we send the correct params via a POST request to `localhost:3000/users/create`, we expect several behaviors:
-   a new record in the `user_events` table, with:
	-   `event_type “Created”`
	-   `payload` with the `user_params`
		-   note that the `password` will be stored as plaintext => **this is UNSAFE BEHAVIOR, and is because we have not implemented bcrypt encryption yet!**
	-   `user_id` with the newly-created User’s `id`
-   a new record in the `user` table, with:
	-   correct `name`
	-   correct `email`
	-   `password_digest` that is the plaintext `password` => **this is UNSAFE BEHAVIOR, and is because we have not implemented bcrypt encryption yet!**

Let’s test it out! 

Fire up `rails s`, and open up Insomnia. 

In our `Create User` request, set the Body to JSON:

![Insomnia page showing Body type being set to JSON](https://dev-to-uploads.s3.amazonaws.com/i/g3rgthzj73uz2dvhn37w.png)

Then, create a JSON hash with a `”user”` key, which points to a hash containing a `”name”`, `”email”`, and `”password”`:

![Insomnia page showing JSON body with user params](https://dev-to-uploads.s3.amazonaws.com/i/dcq61uzaow04u1m6bc7j.png)

Now hit `Send`, and let’s check out our database tables!

First, let’s see if we have an event in our `user_events` table:

![Postico table with first Created event record, overlaid on Insomnia request body](https://dev-to-uploads.s3.amazonaws.com/i/acge8hrnkrq3vm4zsper.png)

So far, so good!
_(Remember: **storing passwords as plaintext is UNSAFE BEHAVIOR, and is because we have not implemented bcrypt encryption yet!**)_

Now, let’s check out the `users` table:

![Postico table with first User record, overlaid on Insomnia request body](https://dev-to-uploads.s3.amazonaws.com/i/d82ai0lxwbhoi50sdvhh.png)

Terrific! We now have our new User, `ongo_gablogian`, and a record of the Event and params that created him!

![gif of Danny DeVito as Ongo Gablogian, a parody of Andy Warhol, on Always Sunny](https://dev-to-uploads.s3.amazonaws.com/i/cl772dunyxs83v8cjb24.gif)

**There you have it! Our event sourcing system is now capturing changes to our data!**

As long as we never alter the data in the `user_events` table, we have a reliable log of how our data got to its current state!

![screenshot of a banner stating MISSION ACCOMPLISHED on Arrested Development](https://dev-to-uploads.s3.amazonaws.com/i/ls69lrx60hiimpan2qpv.jpeg)


# Destroying a User with `Events::User::Destroyed`
Now that we have our pattern in place, it’s very straightforward to create a new Event and record it to our `user_events` table!

Since we **never want to destroy our data**, we implemented a boolean `deleted` field on the User model. When a new User is created, it defaults to `false`.

Let’s create a new event, `Events::User::Destroyed`, that will set the `deleted` field to `true`!

## Create an `app/models/events/user/destroy.rb` file
In the same directory as our `Events::User::Created` class, create an equivalent `Events::User::Destroyed` class:
```ruby
# app/models/events/user/destroy.rb

class Events::User::Destroyed < Events::User::BaseEvent
  def apply(user)
    user
  end
end
```
Above, we start with an `apply` method that simply returns the passed-in User instance.

To delete a User, we’ll simply require an `id`. Let’s add the `payload_attributes` for it:
```ruby
# app/models/events/user/destroy.rb

class Events::User::Destroyed < Events::User::BaseEvent
  payload_attributes :id
end
```

And we’ll make our `apply` method update the passed-in User’s `deleted` field to `true`:
```ruby
# app/models/events/user/destroy.rb

class Events::User::Destroyed < Events::User::BaseEvent
  payload_attributes :id
  
  def apply(user)
    user.deleted = true
    
    user
  end
end
```

That’s it—our new Event is done!


## Update the `destroy` action in `users_controller`
In our `users_controller`, we’ll make our `destroy` action simply create our new `Events::User::Destroyed` event.

Thanks to the `find_or_build_aggregate` and `aggregate_id` methods defined in our top-level BaseEvent, this `”Destroyed”` event will look up a User automatically if a `user_id` argument is supplied.

First, let’s add `id` to the list of strong params in `user_params`:
```ruby
# app/controllers/users_controller.rb

private def user_params
  params.require(:user).permit(:name, :email, :password, :id)
end
```

Now, our controller’s `destroy` action can accept a `user_params` that has the necessary `id`. We’ll also use `user_params[:id]` so the event can look up our target User’s record:
```ruby
# app/controllers/users_controller.rb

def destroy
  Events::User::Destroyed.create(user_id: user_params[:id], payload: user_params)
end
```

We’re ready to go ahead and test with Insomnia!

## Test a DELETE request in Insomnia
Let’s fire up `rails s`. 

Over in Insomnia, create a new request called `Destroy User` and make it a DELETE:

![Insomnia page showing new Destroy User being set to type DELETE](https://dev-to-uploads.s3.amazonaws.com/i/gpddvf8nf4ccuf5orhyh.png)

Set its target URL to `localhost:3000/users/destroy`:

![Insomnia page showing DELETE request's target URL](https://dev-to-uploads.s3.amazonaws.com/i/j6ffh9x0nmfjivrz87bo.png)

Set the Body type to JSON, and add a hash with a `”user”` key pointing to a hash containing the `”id”`:

![Insomnia page showing DELETE request's JSON body with a user id](https://dev-to-uploads.s3.amazonaws.com/i/w3kq02av0bgb0nvmt3p2.png)

Hit Send, and check the database to see if the Event was created:

![Postico user_events table showing new Destroyed event record, overlaid on Insomnia request](https://dev-to-uploads.s3.amazonaws.com/i/tqiyqf7jdsac9oaau0a7.png)

And finally, let’s check the database to see if our User has `deleted` set to `true`:

![Postico users table showing only User record with deleted field set to true](https://dev-to-uploads.s3.amazonaws.com/i/ciri8xikzflbhjhhvx4m.png)

Perfect! We get to keep our User record, but also have it be `deleted`—we’re having our cake, and eating it too!

![screenshot of cake from video game Portal](https://dev-to-uploads.s3.amazonaws.com/i/bruoty5t9v98as079fut.jpg)
_And that's no lie!_

**That’s all it takes to add a new event to our event sourcing system!**


# Conclusion
Wow, we covered a lot of ground! Let’s recap the steps we took to implement our event sourcing system:
-   Create a new Rails app, with a User model and controller, and PostgreSQL for the database
-   Create an `Events::BaseEvent` class in `app/models/events` to handle Event logic:
	-   Looking up or creating aggregates (Users)
	-   Creating getters and setters for `payload_attributes`
	-   Inferring its own `event_type`
	-   Hooks for automatically applying changes and saving to the database
-   Create a `user_events` table migration
-   Create an `Events::User::BaseEvent` to save all Events in its `Events::User::` namespace to the `user_events` table
-   Create an `Events::User::Created` event that will apply `user_params` to a new User instance
-   Create an `Events::User::Destroyed` event that will look up at User by `id` and set its `deleted` field to `true`

This minimal system allows us to do the following:
-   Have a record of events that create and destroy Users
-   Keep all User data permanently, and still have the ability to scope the `deleted` ones as needed
-   A pattern that allows us to easily add new Events that will be saved to the same `user_events` table


# Next Up
We have a lot more we can do to improve our event sourcing system, especially around security and data validations! In the next article, we will cover:
-   Storing sensitive information safely in Event `payloads`, such as passwords
-   Wrapping creating Events in `Commands`, [per Kickstarter’s example]([https://github.com/pcreux/event-sourcing-rails-todo-app-demo/blob/master/app/models/lib/command.rb](https://github.com/pcreux/event-sourcing-rails-todo-app-demo/blob/master/app/models/lib/command.rb))
-   Adding validations to `Commands`



# References
Special thanks to [Philippe Creux](https://kickstarter.engineering/@pcreux) and [Kickstarter](https://kickstarter.engineering/event-sourcing-made-simple-4a2625113224) for sharing [their Event Sourcing example](https://github.com/pcreux/event-sourcing-rails-todo-app-demo).

Thanks to [Martin Fowler](https://martinfowler.com/) for his [important writings](https://martinfowler.com/articles/201701-event-driven.html) on [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html).

Thanks to [Arkency](https://arkency.com/) for their great work with [the RailsEventStore library](https://github.com/RailsEventStore/rails_event_store).

And finally, thanks to fellow Dev.to user [Alfredo Motta](https://dev.to/mottalrd) for [sharing about this years ago](https://dev.to/mottalrd/an-introduction-to-event-sourcing-for-rubyists-41e5) (and keeping it up for me to catch up on!).