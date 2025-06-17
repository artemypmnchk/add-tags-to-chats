#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'logger'
require 'dotenv'
require 'csv'
Dotenv.load

# Класс для работы с API Пачки
class PachcaAPI
  include HTTParty
  base_uri 'https://api.pachca.com/api/shared/v1'
  format :json
  
  attr_reader :logger
  
  def initialize(api_token)
    @api_token = api_token
    @headers = {
      'Authorization' => "Bearer #{api_token}",
      'Content-Type' => 'application/json'
    }
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::INFO
  end
  
  # Получение списка пользователей
  def get_users
    @logger.info("Fetching users from Pachca API...")
    response = self.class.get('/users', headers: @headers)
    handle_response(response)
  end
  
  # Получение всех активных групповых чатов с пагинацией
  def get_all_active_group_chats
    all_chats = []
    page = 1
    per_page = 50
    loop do
      # Если в API есть параметр archived, добавьте archived: false
      response = self.class.get('/chats', headers: @headers, query: { per: per_page, page: page, personal: false })
      data = handle_response(response)
      chats = data["data"] || []
      # Фильтрация по активности (если есть поле archived)
      chats = chats.reject { |chat| chat["archived"] == true } if chats.any? && chats.first.key?("archived")
      all_chats.concat(chats)
      break if chats.size < per_page
      page += 1
    end
    { "data" => all_chats }
  end
  
  # Получение списка чатов
  def get_chats
    @logger.info("Fetching chats from Pachca API...")
    # Запрашиваем максимальное количество чатов на страницу (50)
    response = self.class.get('/chats', headers: @headers, query: { per: 50 })
    handle_response(response)
  end
  
  # Получение участников чата
  def get_chat_members(chat_id)
    response = self.class.get("/chats/#{chat_id}/members", headers: @headers)
    handle_response(response)
  end
  
  # Получение списка тегов
  def get_group_tags
    @logger.info("Fetching tags from Pachca API (with pagination)...")
    all_tags = []
    page = 1
    per_page = 50
    loop do
      response = self.class.get('/group_tags', headers: @headers, query: { per: per_page, page: page })
      data = handle_response(response)
      tags = data["data"] || []
      all_tags.concat(tags)
      break if tags.size < per_page
      page += 1
    end
    { "data" => all_tags }
  end
  
  # Добавление пользователя в чат
  def add_user_to_chat(user_id, chat_id, notify = false)
    @logger.info("Adding user #{user_id} to chat #{chat_id}...")
    body = {
      member_ids: [user_id],
      notify: notify
    }.to_json
    
    response = self.class.post(
      "/chats/#{chat_id}/members",
      headers: @headers,
      body: body
    )
    
    handle_response(response)
  end
  
  # Добавление тега в чат
  def add_tag_to_chat(tag_id, chat_id)
    @logger.info("Adding tag #{tag_id} to chat #{chat_id}...")
    body = {
      group_tag_ids: [tag_id]
    }.to_json
    
    response = self.class.post(
      "/chats/#{chat_id}/group_tags",
      headers: @headers,
      body: body
    )
    
    handle_response(response)
  end
  
  private
  
  def handle_response(response)
    if response.success?
      @logger.info("API request successful")
      begin
        # Проверяем, что тело ответа не пустое
        if response.body.nil? || response.body.empty?
          @logger.info("Response body is empty")
          return {}
        end
        
        parsed_response = JSON.parse(response.body)
        @logger.info("Response body: #{response.body[0..100]}...")
        @logger.info("Parsed response class: #{parsed_response.class}, content: #{parsed_response.inspect[0..100]}...")
        return parsed_response
      rescue => e
        @logger.error("Error parsing response: #{e.message}")
        if response.body
          @logger.error("Response body: #{response.body[0..100]}...")
        else
          @logger.error("Response body is nil")
        end
        # Возвращаем пустой хэш вместо ошибки для пустых ответов
        return {}
      end
    else
      @logger.error("API request failed: #{response.code} - #{response.body}")
      raise "API request failed: #{response.code} - #{response.body}"
    end
  end
end

# Класс для интеграции с Пачкой
class PachcaIntegration
  attr_reader :client, :users, :chats, :tags
  
  def initialize(api_token)
    @client = PachcaAPI.new(api_token)
    @users = nil
    @chats = nil
    @tags = nil
    load_resources
  end
  
  # Загрузка ресурсов из API
  def load_resources
    users_response = @client.get_users
    @users = users_response["data"] if users_response.is_a?(Hash) && users_response["data"]
    
    chats_response = @client.get_all_active_group_chats
    @chats = chats_response["data"] if chats_response.is_a?(Hash) && chats_response["data"]
    
    tags_response = @client.get_group_tags
    @tags = tags_response["data"] if tags_response.is_a?(Hash) && tags_response["data"]
    
    # Создание карт для быстрого доступа
    @user_map = {}
    @users.each { |user| @user_map[user["id"].to_s] = user } if @users.is_a?(Array)
    
    @chat_map = {}
    @chats.each { |chat| @chat_map[chat["id"].to_s] = chat } if @chats.is_a?(Array)
    
    @tag_map = {}
    @tags.each { |tag| @tag_map[tag["id"].to_s] = tag } if @tags.is_a?(Array)
    
    @client.logger.info("Loaded #{@users&.size || 0} users, #{@chats&.size || 0} chats, #{@tags&.size || 0} tags")
  end
  
  # Получение списка пользователей
  def get_users
    return [] unless @users && @users.is_a?(Array)
    
    result = []
    @users.each do |user|
      # Пропускаем заблокированных и ботов
      next if user["suspended"] == true
      next if user["bot"] == true
    begin
        # Если в никнейме есть email, используем его как имя
        if user["nickname"] && user["nickname"].to_s.include?("@")
          name = user["nickname"].to_s.strip
          @client.logger.info("User: #{user["id"]} - Using nickname as name (contains @): #{name}")
          
          result << {
            id: user["id"].to_s,
            name: name
          }
          next
        end
        
        # Формируем имя пользователя из доступных полей
        name_parts = []
        name_parts << user["first_name"] if user["first_name"] && !user["first_name"].to_s.strip.empty?
        name_parts << user["last_name"] if user["last_name"] && !user["last_name"].to_s.strip.empty?
        
        name = name_parts.join(" ").strip
        
        # Если имя пустое, используем никнейм
        if name.empty? && user["nickname"] && !user["nickname"].to_s.strip.empty?
          name = user["nickname"].to_s.strip
        end
        
        # Если имя все еще пустое, используем email
        if name.empty? && user["email"] && !user["email"].to_s.strip.empty?
          name = user["email"].to_s.strip
        end
        
        # Если все еще пусто, используем ID
        name = "User #{user["id"]}" if name.empty?
        
        @client.logger.info("User: #{user["id"]} - Name: #{name}")
        
        result << {
          id: user["id"].to_s,
          name: name
        }
      rescue => e
        @client.logger.error("Error processing user: #{user.inspect} - #{e.message}")
      end
    end
    result
  end
  

  
  # Получение списка чатов
  def get_chats(include_personal = true)
    return [] unless @chats && @chats.is_a?(Array)
    
    result = []
    @chats.each do |chat|
      begin
        # Проверяем, соответствует ли чат фильтру по personal
        personal = chat["personal"] == true
        next if !include_personal.nil? && (include_personal ? !personal : personal)
        
        # Получаем количество участников из поля member_ids
        members_count = 0
        if chat["member_ids"].is_a?(Array)
          members_count = chat["member_ids"].size
          @client.logger.info("Chat #{chat["id"]} (#{chat["name"]}) has #{members_count} members")
        end
        
        result << {
          id: chat["id"].to_s,
          name: chat["name"].to_s,
          personal: personal,
          members_count: members_count
        }
      rescue => e
        @client.logger.error("Error processing chat: #{chat.inspect} - #{e.message}")
      end
    end
    result
  end
  
  # Получение списка тегов
  def get_tags
    return [] unless @tags && @tags.is_a?(Array)
    
    result = []
    @tags.each do |tag|
      begin
        result << {
          id: tag["id"].to_s,
          name: tag["name"].to_s
        }
      rescue => e
        @client.logger.error("Error processing tag: #{tag.inspect} - #{e.message}")
      end
    end
    result
  end
  
  # Добавление пользователя в чат
  def add_user_to_chat(user_id, chat_id, notify = false)
    result = @client.add_user_to_chat(user_id, chat_id, notify)
    
    user = @user_map&.dig(user_id.to_s)
    user_name = user ? "#{user['first_name']} #{user['last_name']}" : "Unknown User"
    chat_name = @chat_map&.dig(chat_id.to_s)&.[]("name") || "Unknown Chat"
    
    {
      success: true,
      user_id: user_id,
      user_name: user_name,
      chat_id: chat_id,
      chat_name: chat_name
    }
  end
  
  # Добавление тега в чат
  def add_tag_to_chat(tag_id, chat_id)
    result = @client.add_tag_to_chat(tag_id, chat_id)
    
    tag = @tag_map&.dig(tag_id.to_s)
    tag_name = tag ? tag['name'] : "Unknown Tag"
    chat_name = @chat_map&.dig(chat_id.to_s)&.[]("name") || "Unknown Chat"
    
    {
      success: true,
      tag_id: tag_id,
      tag_name: tag_name,
      chat_id: chat_id,
      chat_name: chat_name
    }
  end
  
  # Генерация шаблона пользователей
  def generate_users_template(output_file)
    users = get_users
    
    # Записываем в файл
    File.open(output_file, 'w:UTF-8') do |file|
      file.puts "user_id,user_name"
      users.each do |user|
        file.puts "#{user[:id]},#{user[:name]}"
      end
    end
    
    @client.logger.info("Сгенерирован шаблон пользователей: #{output_file} (#{users.size} записей)")
    users
  end
  
  # Генерация шаблона тегов
  def generate_tags_template(output_file)
    tags = get_tags
    
    # Записываем в файл
    File.open(output_file, 'w:UTF-8') do |file|
      file.puts "tag_id,tag_name"
      tags.each do |tag|
        file.puts "#{tag[:id]},#{tag[:name]}"
      end
    end
    
    @client.logger.info("Сгенерирован шаблон тегов: #{output_file} (#{tags.size} записей)")
    tags
  end
  
  # Генерация шаблона чатов
  def generate_chats_template(output_file, filter_personal = nil)
    chats = get_chats(filter_personal)
    
    # Записываем в файл
    File.open(output_file, 'w:UTF-8') do |file|
      file.puts "chat_id,chat_name,members_count"
      chats.each do |chat|
        file.puts "#{chat[:id]},#{chat[:name]},#{chat[:members_count]}"
      end
    end
    
    @client.logger.info("Сгенерирован шаблон чатов: #{output_file} (#{chats.size} записей)")
    chats
  end
  
  # Добавление пользователей в чаты из CSV файла
  def add_users_to_chats(csv_file, notify = false)
    results = { success: [], error: [] }
    
    CSV.foreach(csv_file, headers: true) do |row|
      user_id = row['user_id']
      user_name = row['user_name'] || "Пользователь #{user_id}"
      
      # Проверяем наличие колонки chat_ids (новый формат)
      if row['chat_ids']
        chat_ids = row['chat_ids'].split(';')
        
        # Добавляем пользователя в каждый чат
        chat_ids.each do |chat_id|
          begin
            add_user_to_chat(user_id, chat_id, notify)
            results[:success] << { user_id: user_id, user_name: user_name, chat_id: chat_id, chat_name: @chat_map&.dig(chat_id.to_s)&.dig("attributes", "name") || "Чат #{chat_id}" }
          rescue => e
            results[:error] << { user_id: user_id, chat_id: chat_id, error: e.message }
          end
        end
      else
        # Старый формат с одним чатом
        chat_id = row['chat_id']
        
        begin
          add_user_to_chat(user_id, chat_id, notify)
          results[:success] << { user_id: user_id, user_name: user_name, chat_id: chat_id, chat_name: @chat_map&.dig(chat_id.to_s)&.dig("attributes", "name") || "Чат #{chat_id}" }
        rescue => e
          results[:error] << { user_id: user_id, chat_id: chat_id, error: e.message }
        end
      end
    end
    
    results
  end
  
  # Добавление тегов в чаты из CSV файла
  def add_tags_to_chats(csv_file)
    results = { success: [], error: [] }
    
    CSV.foreach(csv_file, headers: true) do |row|
      tag_id = row['tag_id']
      tag_name = row['tag_name'] || "Тег #{tag_id}"
      
      # Проверяем наличие колонки chat_ids (новый формат)
      if row['chat_ids']
        chat_ids = row['chat_ids'].split(';')
        
        # Добавляем тег в каждый чат
        chat_ids.each do |chat_id|
          begin
            add_tag_to_chat(tag_id, chat_id)
            results[:success] << { tag_id: tag_id, tag_name: tag_name, chat_id: chat_id, chat_name: @chat_map&.dig(chat_id.to_s)&.dig("attributes", "name") || "Чат #{chat_id}" }
          rescue => e
            results[:error] << { tag_id: tag_id, chat_id: chat_id, error: e.message }
          end
        end
      else
        # Старый формат с одним чатом
        chat_id = row['chat_id']
        
        begin
          add_tag_to_chat(tag_id, chat_id)
          results[:success] << { tag_id: tag_id, tag_name: tag_name, chat_id: chat_id, chat_name: @chat_map&.dig(chat_id.to_s)&.dig("attributes", "name") || "Чат #{chat_id}" }
        rescue => e
          results[:error] << { tag_id: tag_id, chat_id: chat_id, error: e.message }
        end
      end
    end
    
    results
  end
end
