class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, 
         :omniauthable, :omniauth_providers => [:facebook]

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  default_scope -> { order(created_at: :desc) }
  validates :email, presence: true, length: { maximum: 255 },
            format: { with: VALID_EMAIL_REGEX },
            uniqueness: true
  #validates :name, length: {maximum: 50}
  
  has_many :notes
  has_many :notebooks
  has_many :comments

  has_many :active_relationships, class_name:  "Relationship",
                                  foreign_key: "follower_id",
                                  dependent:   :destroy

  has_many :passive_relationships, class_name:  "Relationship",
                                   foreign_key: "followed_id",
                                   dependent:   :destroy

  has_many :following, through: :active_relationships, source: :followed

  has_many :followers, through: :passive_relationships, source: :follower

  # Follows a user.
  def follow(other_user)
    active_relationships.create(followed_id: other_user.id)
  end

  # Unfollows a user.
  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user.id).destroy
  end

  # Returns true if the current user is following the other user.
  def following?(other_user)
    following.include?(other_user)
  end

  # Returns a user's status feed.
  def feed
    following_ids = "SELECT followed_id FROM relationships
                     WHERE  follower_id = :user_id"
    Note.includes(:comments).where("notes.user_id IN (#{following_ids})
                     OR notes.user_id = :user_id", user_id: id)
  end

  def largeimage
    "http://graph.facebook.com/#{self.uid}/picture?type=large/"
  end

  def normalimage
    "http://graph.facebook.com/#{self.uid}/picture?type=normal/"
  end

  def self.find_for_facebook_oauth(omniauth)
    puts "yay!!2"
    if user = User.find_by_email(omniauth.info.email)
      if omniauth.info.image.present?
        user.update_attribute(:image, omniauth.info.image)
      end
      user
    else # Create a user with a stub password. 
      User.create!(:email => omniauth.info.email,
                   :name => omniauth.info.name,
                   :avatar => "https://graph.facebook.com/#{auth["uid"]}/picture?type=large",
                   :password => Devise.friendly_token[0,20])
    end
  end

  def self.from_omniauth(auth, signed_in_resource=nil)
    user = User.where(:provider => auth.provider, :uid => auth.uid).first
    if user
      # user.avatar =  "https://graph.facebook.com/#{auth["uid"]}/picture?type=large/"
      user.save
      return user
    else
      registered_user = User.where(:email => auth.info.email).first
      if registered_user
        return registered_user
      else

        user = User.create(
          name:auth.extra.raw_info.name,
          # uid:auth.uid,
          email:auth.info.email,
          avatar: "https://graph.facebook.com/#{auth["uid"]}/picture?type=large/",
          password:Devise.friendly_token[0,20]
          )
      end    
    end
  end



  def self.new_with_session(params, session)
    puts "yay!!5"
   
    super.tap do |user|
      if omniauth = session["devise.facebook_data"]
        user.email = omniauth.info.email
        user.name = omniauth.info.name
        # user.avatar = omniauth.info.image
      end
    end
  end

  has_attached_file :avatar, :styles => { :medium => "400x400>", :thumb => "400x400" }, :default_url => ActionController::Base.helpers.asset_path('missing.png')
  validates_attachment_content_type :avatar, :content_type => /\Aimage\/.*\Z/


end
