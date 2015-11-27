#!/usr/bin/env ruby

# file: gtk2html.rb

require 'gtk2svg'
require 'htmle'


module Gtk2HTML

  class Render < DomRender

    def initialize(x, width, height)
      
      @width, @height = width, height
      super x
      
    end    
    
    def body(e, attributes, raw_style)

      style = style_filter(attributes).merge(raw_style)

      h = attributes
      
      [[:draw_box, [x1,y1,x2,y2], style], render_all(e)]
    end    

    def div(e, attributes, raw_style)
      
      style = style_filter(attributes).merge(raw_style)
      margin = style[:margin].values
      coords = [0, nil, @width, @height/2]
      padding = style[:padding].values
      
      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end
    
    def html(e, attributes, style)   

      margin = style[:margin].values
      coords = [0, 0, @width, @height]
      padding = style[:padding].values

      [[:draw_box, margin, coords, padding, style], render_all(e)]
    end    
    
    private
    
    def fetch_style(attribute)
      
      h = super attribute

      %i(margin padding).inject(h) do |r,x|

        if h.has_key? x then

          a = expand_shorthand(h[x]) 
          a.map!(&:to_i) # assumes everything is in pixels not em
          r.merge!(x => Hash[%i(top right bottom left).zip(a)])
        else
          r
        end

      end
      
    end    
    
    def style_filter(attributes)
      
      %i(bgcolor).inject({}) do |r,x|
        attributes.has_key?(x) ? r.merge(x => attributes[x]) : r          
      end
      
    end    
    
  end
  
  class Layout
    
    attr_reader :to_a
    
    def initialize(instructions, width: 320, height: 240)
      
      @width, @height = width, height
      a = lay_out(instructions, pcoords: [0, 0, @width, @height])
      @to_a = a
      
    end
    

    private

    def lay_out(a, pcoords: [])

      item, children = a
      
      name, margin, raw_coords, padding, style = item
      
      coords = raw_coords.map.with_index {|x,i| x ? x : pcoords[i]}
      
      x1 = coords[0] + margin[0]
      y1 = coords[1] + margin[1]
      x2 = coords[2] - margin[2]
      y2 = coords[3] - margin[3]      

      item[2] = [x1, y1, x2, y2]

      nested = if children and children.length > 1 then
        lay_out(children, pcoords: coords) 
      else
        children
      end
      #[owidth=(coords[2] - coords[0]), oheight=(coords[3] - coords[1])]
      r = [item]
      r << nested if nested
      r
    end    
    
    def lay_out2(a, pcoords: [])
      
      name, raw_coords, attributes, style, children = a
      coords = raw_coords.map.with_index {|x,i| x ? x : pcoords[i]}

      owidth, oheight = lay_out(children, pcoords: coords) if children
      
      [(coords[2] - coords[0]), (coords[3] - coords[1])]
    end    
    
  end
  
  class DrawingInstructions

    attr_accessor :area


    def initialize(area=nil)

      @area = area if area

    end    
    
    def draw_box(margin, raw_coords, padding, style)

      coords = raw_coords.map.with_index {|x,i| x ? x : @curpos[i] }

      h2 = style.clone
      h2.delete :color
      x1, y1, x2, y2 = coords
      
      @curpos = coords

      width = x2 - x1
      height = y2 - y1

      gc = gc_ini(h2)
      @area.window.draw_rectangle(gc, 1, x1, y1, width, height)
    end
    
    def draw_layout(text, style)

      x, y = @curpos

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
      draw [a]
    end
    
    def script(args)

    end    
    
    
    private
    
    def draw(a)
      
      return unless a
      
      a.each do |row|
        
        next unless row
        x, remaining = row

        case x[0].class.to_s.to_sym

        when :Symbol
          
          name, *args = x
                  
          @latest_style = args[3]

          method(name).call(*args)
          draw remaining
          
        when :String then

          next if x.empty?

          method(:draw_layout).call(x, @latest_style)

        when :Array
          draw remaining
        else    
          
          name, *args = x

          method(name).call(args)
          draw remaining
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

        drawing = DrawingInstructions.new area
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