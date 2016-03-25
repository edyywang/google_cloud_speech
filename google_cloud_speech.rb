# load 'google_cloud_vision.rb'
# api = GoogleCloudVision.new # default as LABEL_DETECTION
# api = GoogleCloudVision.new('SAFE_SEARCH_DETECTION')
# api.upload_file('sample.jpg') # file name under images folder

require 'dotenv'
require 'google/apis/drive_v2'
require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'base64'

class GoogleCloudSpeech

  Dotenv.load
  SERVICE_ACCOUNT_EMAIL = ENV['SERVICE_ACCOUNT_EMAIL']
  SERVICE_ACCOUNT_KEY = ENV['SERVICE_ACCOUNT_KEY']
  BROWSER_API_KEY = ENV['BROWSER_API_KEY']
  REQUEST_FILE_NAME = 'request.txt'
  FILE_FOLDER = 'images/'

  TYPE_UNSPECIFIED = 'TYPE_UNSPECIFIED'	# Unspecified feature type.
  FACE_DETECTION = 'FACE_DETECTION'	# Run face detection.
  LANDMARK_DETECTION = 'LANDMARK_DETECTION'	# Run landmark detection.
  LOGO_DETECTION = 'LOGO_DETECTION'	# Run logo detection.
  LABEL_DETECTION = 'LABEL_DETECTION'	# Run label detection.
  TEXT_DETECTION = 'TEXT_DETECTION'	# Run OCR.
  SAFE_SEARCH_DETECTION = 'SAFE_SEARCH_DETECTION'	# Run various computer vision models to compute image safe-search properties.
  IMAGE_PROPERTIES = 'IMAGE_PROPERTIES'	# Compute a set of properties about the image (such as the image's dominant colors).

  def initialize(type = LABEL_DETECTION)
    @type = type
  end

  def upload_file(file_name = 'sample.jpg')
    file_path = "#{FILE_FOLDER}#{file_name}"
    process_image_file(file_path, REQUEST_FILE_NAME)

    api_url = URI("https://vision.googleapis.com/v1/images:annotate?key=#{BROWSER_API_KEY}")
    http = Net::HTTP.new(api_url.host, api_url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(api_url)
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    request.body = File.read(REQUEST_FILE_NAME)
    response = http.request(request)
    if response.code.start_with?('20')
      process_result(response.read_body)
    else
      fail "FAILED: #{response.read_body}"
    end
  end

  def process_image_file(file_path, request_file_name)
    image_file = Base64.encode64( File.open(file_path, 'rb') {|file| file.read } ).strip
    request_json = JSON.generate("requests" => [{
                                              "image" => { "content" => "#{image_file}" },
                                              "features" => [{ "type" => "#{@type}", "maxResults" => "#{max_results}" }]
                                            }])
    File.open(request_file_name,"w") do |f|
      f.write(request_json)
    end
  end

  def max_results
    case @type
    when 'LABEL_DETECTION'
      5
    when 'SAFE_SEARCH_DETECTION'
      1
    else
      3
    end
  end

  def process_result(response_read_body)
    case @type
    when 'LABEL_DETECTION'
      process_label_detection(response_read_body)
    when 'SAFE_SEARCH_DETECTION'
      process_safe_search_detection(response_read_body)
    else
      puts "#{response_read_body}"
    end
  end

  def process_label_detection(response_read_body)
    result = JSON.parse(response_read_body).to_hash
    description = result['responses'].first['labelAnnotations'].first['description']
    score = result['responses'].first['labelAnnotations'].first['score']

    puts "description: #{description}"
    puts "score: #{score}"

    puts "========RESULT========"
    puts "#{response_read_body}"
  end

  def process_safe_search_detection(response_read_body)
    result = JSON.parse(response_read_body).to_hash
    adult = result['responses'].first['safeSearchAnnotation']['adult']
    spoof = result['responses'].first['safeSearchAnnotation']['spoof']
    medical = result['responses'].first['safeSearchAnnotation']['medical']
    violence = result['responses'].first['safeSearchAnnotation']['violence']
    content_safe = adult.include?('UNLIKELY') and spoof.include?('UNLIKELY') and medical.include?('UNLIKELY') and violence.include?('UNLIKELY')

    if content_safe
      puts "content save"
    else
      puts "adult: #{adult}" unless adult.include? 'UNLIKELY'
      puts "spoof: #{spoof}" unless spoof.include? 'UNLIKELY'
      puts "medical: #{medical}" unless medical.include? 'UNLIKELY'
      puts "violence: #{violence}" unless violence.include? 'UNLIKELY'
    end

    puts "========RESULT========"
    puts "#{response_read_body}"
  end
end
