class TwitPic
  
  def initialize(login, password)
    @username, @password = login, password
  end
  
  def upload(photo)
    `curl -F media=@#{photo.path} -F username=#{@username} -F password=#{@password} -F message='#{photo.title}' http://twitpic.com/api/uploadAndPost`
  end
  
end