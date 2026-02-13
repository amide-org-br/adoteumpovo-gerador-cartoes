#!/usr/bin/ruby
# frozen_string_literal: true

require 'open-uri'
require 'rmagick'

class CartaoPovo
  include Magick
  include ActiveSupport::NumberHelper

  NO_DATA_MESSAGE = 'SEM INFORMAÇÃO'

  def initialize
    @text_title_font_size = 60
    @text_box_width = 489
    @offset_x_titulo = 580
    @path_flags = 'gerador/flags'
    @path_photos = 'gerador/photos'
    @path_cards = 'gerador/prayer_cards'
    @template_cartao = ImageList.new 'gerador/templates/template_cartao.png'
    @template_fundo_bandeira = ImageList.new 'gerador/templates/template_fundo_bandeira.png'
    @template_texto_alianca_adocao = ImageList.new 'gerador/templates/template_texto_alianca_adocao.png'
  end

  def gerar_bandeiras(pnas)
    pnas.each do |pna|
      flag_file_name = "gerador/flags/flag_#{pna.country_code_2}.png"
      next if File.exist? flag_file_name
      begin
        flag_img = Image.from_blob(URI.open(pna.flag_url).read)[0]
        flag_img.resize_to_fit! 323, 215 # converte para tamanho esperado
        flag_img.write flag_file_name
      rescue
        pna.has_invalid_flag_url = true
        pna.save
      end
    end
    # https://www.cia.gov/library/publications/the-world-factbook/attachments/flags/SF-flag.jpg
  end

  def gerar_bandeira_e_foto(pnas)
    pnas.each do |pna|
      begin
        unless pna.photo_url.nil?
          photo_img = Image.from_blob(URI.open(pna.photo_url).read)[0]
          photo_img.resize! 538, 664
          photo_img.write "gerador/photos/photo_#{pna.id}.png"
        end
      rescue
        pna.has_invalid_photo_url = true
        pna.save
      end

      flag_file_name = "gerador/flags/flag_#{pna.country_code_2}.png"
      next if File.exist? flag_file_name

      begin
        flag_img = Image.from_blob(URI.open(pna.flag_url).read)[0]
        flag_img.resize_to_fit! 323, 215 # converte para tamanho esperado
        flag_img.write flag_file_name
      rescue
        pna.has_invalid_flag_url = true
        pna.save
      end
    end
  end

  def inserir_imagens_templates
    # inserir_imagem_cartao @template_fundo_bandeira, 640, 40
    inserir_imagem_cartao @template_texto_alianca_adocao, 560, 300
  end

  def carregar_imagens_povo(pna)
    @photo = ImageList.new "#{@path_photos}/photo_#{pna.id}.png" unless pna.photo_url.nil?
    @flag = ImageList.new "#{@path_flags}/flag_#{pna.country_code_2}.png"
  end

  def gravar_carta_povo(pna_id)
    @template_cartao.write "#{@path_cards}/carta_povo_#{pna_id}.png"
  end

  def gerar_cartao_povo(pna)
    inserir_imagens_templates
    carregar_imagens_povo pna
    inserir_imagens_cartao
    escrever_informacoes_povo pna
    gravar_carta_povo pna.id
  end

  def gerar_caneta(font_weight, font_size)
    font_writer = Magick::Draw.new
    font_writer.font_family 'Helvetica'
    font_writer.gravity = NorthGravity
    font_writer.align = LeftAlign
    font_writer.fill = '#414c47' #green

    font_writer.font_weight = font_weight
    font_writer.pointsize = font_size

    font_writer
  end

  def escrever_informacoes_povo(pna)
    # nome povo - topo
    escrever_titulo_povo pna.peop_name_in_country.capitalize
    # pais povo - topo
    escrever_titulo_pais pna.country.upcase, pna.peop_name_in_country.capitalize

    # country/pais
    escrever_texto 182, 910, pna.country.upcase
    # people name/povo
    escrever_texto 678, 910, pna.peop_name_in_country.upcase

    # population/populacao
    population = pna.population.nil? ? NO_DATA_MESSAGE : number_to_human(pna.population, {locale: 'pt-BR'}).upcase
    escrever_texto 182,1140, population
    # primary religion/religiao primaria
    primary_religion = pna.primary_religion.nil? ? NO_DATA_MESSAGE : pna.primary_religion.upcase
    escrever_texto 678,1140, primary_religion

    # jesus film/possui filme jesus
    escrever_texto 182,1420, boolean(pna.has_jesus_movie_translated)
    # 10/40 window/localizado janela 10/40
    escrever_texto 678,1420, boolean(pna.in_window_10_40)

    # adoption date
    # escrever_texto 750, 1610, Date.today.strftime('%d/%m/%Y')
  end

  def boolean(val)
    val ? 'SIM' : 'NÃO'
  end

  def escrever_titulo_povo(texto)
    escrever_titulo @offset_x_titulo, 595, texto, BoldWeight
  end

  def escrever_titulo_pais(texto, titulo_povo)
    text = fit_text(titulo_povo, @text_box_width, BoldWeight, @text_title_font_size)
    offset_y_lines = height_titulo_povo(text)
    offset_y = 612
    escrever_titulo @offset_x_titulo, offset_y + offset_y_lines, texto
  end

  def escrever_titulo(offset_x, offset_y, texto, font_weight=NormalWeight)
    font_size = 60
    caneta = gerar_caneta(font_weight, font_size)
    caneta.annotate @template_cartao, @text_box_width, @text_title_font_size, offset_x, offset_y, fit_text(texto, @text_box_width, font_weight, font_size)
  end

  def escrever_texto(offset_x, offset_y, texto)
    text_height = 60
    font_size = 35
    font_weight = BoldWeight
    caneta = gerar_caneta(font_weight, font_size)
    caneta.annotate @template_cartao, @text_box_width, text_height, offset_x, offset_y, fit_text(texto, @text_box_width, font_weight, font_size)
  end

  def inserir_imagens_cartao
    inserir_foto_cartao @photo unless @photo.nil?
    inserir_bandeira_cartao @flag
  end

  def inserir_foto_cartao(img)
    inserir_imagem_cartao img, -2, -4
  end

  def inserir_bandeira_cartao(img)
    inserir_imagem_cartao img,650, 40
  end

  def inserir_imagem_cartao(img, pos_x, pos_y)
    @template_cartao.composite! img, NorthWestGravity, pos_x, pos_y, OverCompositeOp
  end

  def text_fit?(text, width, font_weight, font_size)
    tmp_image = Image.new(width, 500)
    drawing = Draw.new
    drawing.gravity = Magick::NorthGravity
    drawing.pointsize = font_size
    drawing.font_family = 'helvetica'
    drawing.font_weight = font_weight
    drawing.annotate(tmp_image, 0, 0, 0, 0, text)
    metrics = drawing.get_multiline_type_metrics(tmp_image, text)
    (metrics.width < width)
  end

  def height_titulo_povo(text)
    tmp_image = Image.new(@text_box_width, 600)
    drawing = Draw.new
    drawing.gravity = Magick::NorthGravity
    drawing.pointsize = @text_title_font_size
    drawing.font_family = 'helvetica'
    drawing.font_weight = BoldWeight
    drawing.annotate(tmp_image, 0, 0, 0, 0, text)
    drawing.get_multiline_type_metrics(tmp_image, text).height
  end

  def fit_text(text, width, font_weight, font_size)
    separator = ' '
    line = ''

    if not text_fit?(text, width, font_weight, font_size) and text.include? separator
      i = 0
      text.split(separator).each do |word|
        if i == 0
          tmp_line = line + word
        else
          tmp_line = line + separator + word
        end

        if text_fit?(tmp_line, width, font_weight, font_size)
          unless i == 0
            line += separator
          end
          line += word
        else
          unless i == 0
            line +=  '\n'
          end
          line += word
        end
        i += 1
      end
      text = line
    end
    text
  end

end

def humanize secs
  [[60, :segundos], [60, :minutos], [24, :horas], [Float::INFINITY, :dias]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}" unless n.to_i == 0
    end
  }.compact.reverse.join(' ')
end

inicio = Time.now
puts "início: #{inicio}"

tempo_geracao_cartoes = []
i = 0

pnas = Pna.all
# pnas = []
# pnas << Pna.find(119)
pnas.each do |pna|
  tempo_geracao_cartoes[i] = Time.now
  cartao = CartaoPovo.new
  cartao.gerar_cartao_povo pna
  tempo_geracao_cartoes[i] = "#{humanize(tempo_geracao_cartoes[i] - inicio)}"
  i += 1
end

fim = Time.now
puts "fim: #{fim}"
puts "Estatísticas:"
puts "Tempo gasto total: #{humanize(fim - inicio)}"
puts "Tempos gastos para gerar cartão por povo:"
tempo_geracao_cartoes.each_with_index do |tempo_pna, i|
  puts "#{i+1}º povo gerado depois de #{tempo_pna}"
end

# Geracao dos cartoes:
# início: 2020-09-11 08:57:06 -0300
# fim: 2020-09-11 15:20:42 -0300
# Estatísticas:
# Tempo gasto total: 6 horas 23 minutos 35 segundos

# puts "#{Pna.total_povos_sem_foto} povos SEM foto de um total de #{Pna.all.count} povos."
# puts "#{Pna.total_povos_foto_nula} povos foto NULA de um total de #{Pna.all.count} povos."
# puts "#{Pna.total_povos_url_foto_invalida} povos URL foto INVALIDA de um total de #{Pna.all.count} povos."
# puts "#{Pna.total_povos_url_bandeira_invalida} povos URL bandeira INVALIDA de um total de #{Pna.all.count} povos."
