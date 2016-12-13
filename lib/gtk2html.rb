#!/usr/bin/env ruby

# file: gtk2html.rb

require 'gtk2svg'
require 'htmle'


# module InspectArray is located in dom_render.rb


module Gtk2HTML

  class Render < DomRender

    def initialize(x, width, height)
      
      @width, @height = width.to_i, height.to_i
      super x
      
    end    
    
    def body(e, attributes, raw_style)

      style = style_filter(attributes).merge(raw_style)
      margin = style[:margin].values
      coords = [nil, nil, nil, nil]
      padding = style[:padding].values
      
      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end    
    
    def strong(e, attributes, raw_style)

      style = style_filter(attributes).merge(raw_style)
      margin = style[:margin].values
      coords = [nil, nil, nil, nil]
      padding = style[:padding].values
      
      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end      
    
    alias b strong

    def div(e, attributes, raw_style)

      style = style_filter(attributes).merge(raw_style)
      margin = style[:margin].values
      coords = [nil, nil, nil, nil]
      padding = style[:padding].values
      
      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end
    
    def html(e, attributes, style)   

      margin = [0, 0, 0, 0] # style[:margin].values
      coords = [0, 0, @width, @height]
      padding = [0, 0, 0, 0] # style[:padding].values

      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end

    def style(*args)
      
    end
    
    private
    
    def fetch_style(attribute)
      
      h = super attribute

      r2 = %i(margin padding).inject(h) do |r,x|

        if h.has_key? x then

          a = expand_shorthand(h[x]) 

          a.map! do |v|
            # note: there is 16px in 1em, see http://pxtoem.com/
            v =~ /em$/i ? v.to_f * 16 : v.to_f
          end

          r.merge!(x => Hash[%i(top right bottom left).zip(a)])
        else
          r
        end

      end

      r3 =  %i(height width).inject(r2) do |r,x|

        if r.has_key? x then

          v = r[x]

          # note: there is 16px in 1em, see http://pxtoem.com/
          r[x] = v =~ /em$/i ? v.to_f * 16 : v.to_f          
          r

        else
          r
        end

      end      
      
      r3
      
    end    
    
    def style_filter(attributes)
      
      %i(bgcolor).inject({}) do |r,x|
        attributes.has_key?(x) ? r.merge(x => attributes[x]) : r          
      end
      
    end    
    
  end
  
  class Layout
    include InspectArray
    
    attr_reader :to_a
    
    def initialize(instructions, width: 320, height: 240)
      
      pcoords = [0, 0, width, height]
      @pcoords = [0,0,0,0]      
      a = lay_out(instructions, pcoords)
      @a = del_pcoords a

    end
    
    def to_a(inspect: false, verbose: false)
      
      if inspect or verbose then
        scan @a
        puts
        @a
      else
        @a
      end

    end
    

    private
    
    def del_pcoords(a)

      if a.first.is_a? Array then
        a.map {|row| del_pcoords row if row}
      else
        a.pop
        a
      end
    end

    def lay_out(a, pcoords=[])

      if a.first.is_a? Symbol then
        
        @text_style = %i(font-size color).inject({})\
                                                 {|r,x| r.merge(x => a[4][x]) }
        set_row(a, pcoords)
        
      elsif a.first.is_a? String then
        
        [a.first, @pcoords.take(2), @text_style, pcoords]
        
      elsif a.first.is_a? Array 

        if a.first.empty? then
          a.delete a.first
          lay_out a, pcoords
        else
          
          if a.first.first.is_a? Symbol then            
            
            item, children = a

            r = lay_out(item, pcoords)

            pcoords = r[-1]

            if children.any? then

              r2 = lay_out(children, pcoords) 
              r = [r,r2]
            else
              r
            end

            #r << pcoords
            
          else
            a.map do |row| 
              row2 =lay_out(row, pcoords) 
              pcoords[1] = row2[1][2]
              row2
            end
          end

        end

      else

        a.map {|row| lay_out(row, pcoords) }

      end
      
    end         
    
    def set_row(row, pcoords)
      
      name, margin, raw_coords, padding, style = row
    
      coords = raw_coords.map.with_index {|x,i| x ? x : pcoords[i]}
      
      width, height = style[:width], style[:height]
      
      x1 = coords[0] + margin[0]
      y1 = coords[1] + margin[1]
      
      if width then

        x2 = x1 + width.to_f
        x2 += margin[2]        
      else
        x2 = coords[2] - margin[2]
      end
      
      if height then

        y2 = y1 + height.to_f
        y2 += margin[3]

      else
        y2 = coords[3] - margin[3]      
      end

      new_coords = [x1, y1, x2, y2]        
      
      @pcoords[0] = x1 + padding[0]
      @pcoords[1] = y1 + padding[1]
      @pcoords[2] = x2 - padding[2]
      @pcoords[3] = y2 - padding[3]      
      pcoords = @pcoords.clone

      [name, margin, new_coords, padding, style, pcoords]

    end
    
  end
  
  class DrawingInstructions

    attr_accessor :area


    def initialize(area=nil)

      @area = area if area

    end    
    
    def draw_box(margin, coords, padding, style)

      h2 = style.clone
      h2.delete :color

      x1, y1, x2, y2 = coords

      width = x2 - x1
      height = y2 - y1

      gc = gc_ini(h2)
      @area.window.draw_rectangle(gc, 1, x1, y1, width, height)
    end
    
    def draw_layout(text, coords, style)

      x, y = coords
    
      text ||= ''
      h2 = style.clone
      h2.delete :'background-color'      
      
      layout = Pango::Layout.new(Gdk::Pango.context)
      layout.font_description = Pango::FontDescription.\
                                             new('Sans ' + style[:'font-size'])
      layout.text = text
            
      gc = gc_ini(h2)
      @area.window.draw_layout(gc, x, y, layout)
    end          
    
    def window(args)
    end

    def render(a)      
      draw a
    end
    
    def script(args)

    end    
    
    
    private
    
    def draw(a)
            
      return unless a
      
      if a.first.is_a? Symbol then
        
        name, margin, coords, padding, style, _, *children = a                  
        method(name).call(margin, coords, padding, style)
        draw children
        
      elsif a.first.is_a? String and not a.first.empty?

        coords, style = a[1..-1]#remaining
        method(:draw_layout).call(a.first, coords, style)
        
      else
      
        a.each do |row|

          next unless row

          x = row

          case row[0].class.to_s.to_sym

          when :Symbol
            
            name, margin, coords, padding, style, _, *children = x
                    
            method(name).call(margin, coords, padding, style)
            draw children
            
          when :'Rexle::Element::Value' then

            next if x.empty?

            coords, style = row[1..-1]#remaining
            
            method(:draw_layout).call(*row)

          when :Array

            if row[-1][0].is_a? String then
              method(:draw_layout).call(*row[-1])
            else
              draw row[-1]
            end
          else    
            
            name, *args = x

            method(name).call(args)
            draw row[-1]
          end

        end
      end
        
    end
    
    def set_colour(c)

      colour = case c
      when /^rgb/
        regex = /rgb\((\d{1,3}), *(\d{1,3}), *(\d{1,3})\)$/
        r, g, b = c.match(regex).captures.map {|x| x.to_i * 257}
        colour = Gdk::Color.new(r, g, b)
      when /^#/
          Gdk::Color.parse(c)
      else
          Gdk::Color.parse(c)
      end
      
      colormap = Gdk::Colormap.system
      colormap.alloc_color(colour,   false, true)

      colour
    end    

    def gc_ini(style)
      
      gc = Gdk::GC.new(@area.window)

      color, bgcolor = style[:color], style[:'background-color']

      gc.set_foreground(set_colour(color)) if color
      gc.set_foreground(set_colour(bgcolor)) if bgcolor
      
      gc
    end
    
  end
  
  class Main
    
    
    attr_accessor :doc, :html
    attr_reader :width, :height, :window
    
    def initialize(html, irb: false)
      
      @html = html
      @doc = Htmle.new(html, callback: self)

      @area = area = Gtk::DrawingArea.new
      client_code = []
      
      window = Gtk::Window.new
      
      @width = 320
      @height = 240
      @window = window
      window.set_default_size(@width, @height)
      
      @dirty = true


      area.signal_connect("expose_event") do      
        
        width, height = window.size

        @dirty = true if [@width, @height] != [width, height]

        
        if @dirty then

          Thread.new { @doc.root.xpath('//script').each {|x| eval x.text.unescape } }
          
          @width, @height = window.size
          instructions = Gtk2HTML::Render.new(@doc, @width, @height).to_a

          @layout_instructions = Gtk2HTML::Layout.new(instructions).to_a

        end

        drawing = Gtk2HTML::DrawingInstructions.new area
        drawing.render @layout_instructions
        @dirty = false
        
      end

      area.add_events(Gdk::Event::POINTER_MOTION_MASK) 

      area.signal_connect('motion_notify_event') do |item,  event|

        @doc.root.xpath('//*[@onmousemove]').each do |x|
                    
          eval x.onmousemove() if x.hotspot? event.x, event.y
          
        end
      end

      area.add_events(Gdk::Event::BUTTON_PRESS_MASK) 

      area.signal_connect "button_press_event" do |item,event| 

        @doc.root.xpath('//*[@onmousedown]').each do |x|
                    
          eval x.onmousedown() if x.hotspot? event.x, event.y
          
        end        
      end     
      
      window.add(area).show_all
      window.show_all.signal_connect("destroy"){Gtk.main_quit}

      irb ? Thread.new {Gtk.main  } : Gtk.main
    end
    
    def onmousemove(x,y)
      
    end
    
    def refresh()
      @dirty = true
      @area.queue_draw
    end
    
    def html=(html)
      @html = html
      @doc = Htmle.new(svg, callback: self)
    end
    
  end  
  
end