#--
# vim:ts=4:sw=4:et:smartindent:nowrap
#++
# Various helper functions

  # Returns the current Document object
  def get_document()
      Kamelopard::DocumentHolder.instance.current_document
  end
  
  # Changes the default FlyTo mode. Possible values are :smooth and :bounce
  def set_flyto_mode_to(mode)
      Kamelopard::DocumentHolder.instance.current_document.flyto_mode = mode
  end
  
  # Shows or hides the popup balloon for Placemark and ScreenOverlay objects.
  # Arguments are the object; 0 or 1 to hide or show the balloon, respectively;
  # and a hash of options to be added to the AnimatedUpdate object this
  # function creates. Refer to the AnimatedUpdate documentation for details on
  # possible options.
  def toggle_balloon_for(obj, value, options = {})
      au = Kamelopard::AnimatedUpdate.new [], options
      if ! obj.kind_of? Kamelopard::Placemark and ! obj.kind_of? Kamelopard::ScreenOverlay then
          raise "Can't show balloons for things that aren't Placemarks or ScreenOverlays"
      end
      a = XML::Node.new 'Change'
      # XXX This can probably be more robust, based on just the class's name
      if obj.kind_of? Kamelopard::Placemark then
          b = XML::Node.new 'Placemark'
      else
          b = XML::Node.new 'ScreenOverlay'
      end
      b.attributes['targetId'] = obj.kml_id
      c = XML::Node.new 'gx:balloonVisibility'
      c << XML::Node.new_text(value.to_s)
      b << c
      a << b
      au << a
  end
  
  # Hides the popup balloon for a Placemark or ScreenOverlay object. Require
  # the object as the first argument, and takes a hash of options passed to the
  # AnimatedUpdate object this functino creates. See also show_balloon_for and
  # toggle_balloon_for
  def hide_balloon_for(obj, options = {})
      toggle_balloon_for(obj, 0, options)
  end
  
  # Displays the popup balloon for a Placemark or ScreenOverlay object. Require
  # the object as the first argument, and takes a hash of options passed to the
  # AnimatedUpdate object this functino creates. See also show_balloon_for and
  # toggle_balloon_for
  def show_balloon_for(obj, options = {})
      toggle_balloon_for(obj, 1, options)
  end
  
  # Fades a placemark's popup balloon in or out. Takes as arguments the
  # placemark object, 0 or 1 to hide or show the balloon, respectively, and a
  # has of options to be passed to the AnimatedUpdate object created by this
  # function. In order to have the balloon fade over some noticeable time, at
  # minimum the :duration attribute in this hash should be set to some
  # meaningful number of seconds.
  def fade_balloon_for(obj, value, options = {})
      au = Kamelopard::AnimatedUpdate.new [], options
      if ! obj.is_a? Kamelopard::Placemark then
          raise "Can't show balloons for things that aren't placemarks"
      end
      a = XML::Node.new 'Change'
      b = XML::Node.new 'Placemark'
      b.attributes['targetId'] = obj.kml_id
      c = XML::Node.new 'color'
      c << XML::Node.new_text(value.to_s)
      b << c
      a << b
      au << a
  end
  
  # Refer to fade_balloon_for. This function only fades the balloon out.
  def fade_out_balloon_for(obj, options = {})
      fade_balloon_for(obj, '00ffffff', options)
  end
  
  # Refer to fade_balloon_for. This function only fades the balloon in.
  def fade_in_balloon_for(p, options = {})
      fade_balloon_for(p, 'ffffffff', options)
  end
  
  # Creates a Point object. Arguments are latitude, longitude, altitude,
  # altitude mode, and extrude
  def point(lo, la, alt=0, mode=nil, extrude = false)
      m = ( mode.nil? ? :clampToGround : mode )
      Kamelopard::Point.new(lo, la, alt, :altitudeMode => m, :extrude => extrude)
  end
  
  # Creates a Placemark with the given name. Other Placemark attributes are set
  # in the options hash.
  def placemark(name = nil, options = {})
      Kamelopard::Placemark.new name, options
  end
  
  # Returns the KML that makes up the current Kamelopard::Document
  def get_kml
      Kamelopard::DocumentHolder.instance.current_document.get_kml_document
  end
  
  # Returns the KML that makes up the current Document, as a string
  def get_kml_string
      get_kml.to_s
  end
  
  # Inserts a KML gx:Wait element
  def pause(p)
      Kamelopard::Wait.new p
  end
  
  # Returns the current Tour object
  def get_tour()
      Kamelopard::DocumentHolder.instance.current_document.tour
  end
  
  # Sets a name for the current Tour
  def name_tour(name)
      Kamelopard::DocumentHolder.instance.current_document.tour.name = name
  end
  
  # Returns the current Folder object
  def get_folder()
      f = Kamelopard::DocumentHolder.instance.current_document.folders.last
      Kamelopard::Folder.new() if f.nil?
      Kamelopard::DocumentHolder.instance.current_document.folders.last
  end
  
  # Creates a new Folder with the current name
  def folder(name)
      Kamelopard::Folder.new(name)
  end
  
  # Names (or renames) the current Folder, and returns it
  def name_folder(name)
      Kamelopard::DocumentHolder.instance.current_document.folder.name = name
      return Kamelopard::DocumentHolder.instance.current_document.folder
  end
  
  # Names (or renames) the current Document object, and returns it
  def name_document(name)
      Kamelopard::DocumentHolder.instance.current_document.name = name
      return Kamelopard::DocumentHolder.instance.current_document
  end
  
  def zoom_out(dist = 1000, dur = 0, mode = nil)
      l = Kamelopard::DocumentHolder.instance.current_document.tour.last_abs_view
      raise "No current position to zoom out from\n" if l.nil?
      l.range += dist
      Kamelopard::FlyTo.new(l, nil, dur, mode)
  end
  
  # Creates a list of FlyTo elements to orbit and look at a given point (center),
  # at a given range (in meters), starting and ending at given angles (in
  # degrees) from the center, where 0 and 360 (and -360, and 720, and -980, etc.)
  # are north. To orbit clockwise, make startHeading less than endHeading.
  # Otherwise, it will orbit counter-clockwise. To orbit multiple times, add or
  # subtract 360 from the endHeading. The tilt argument matches the KML LookAt
  # tilt argument
  def orbit(center, range = 100, tilt = 0, startHeading = 0, endHeading = 360)
      fly_to Kamelopard::LookAt.new(center, startHeading, tilt, range), 2, nil
  
      # We want at least 5 points (arbitrarily chosen value), plus at least 5 for
      # each full revolution
  
      # When I tried this all in one step, ruby told me 360 / 10 = 1805. I'm sure
      # there's some reason why this is a feature and not a bug, but I'd rather
      # not look it up right now.
      num = (endHeading - startHeading).abs
      den = ((endHeading - startHeading) / 360.0).to_i.abs * 5 + 5
      step = num / den
      step = 1 if step < 1
      step = step * -1 if startHeading > endHeading
  
      lastval = startHeading
      startHeading.step(endHeading, step) do |theta|
          lastval = theta
          fly_to Kamelopard::LookAt.new(center, theta, tilt, range), 2, nil, 'smooth'
      end
      if lastval != endHeading then
          fly_to Kamelopard::LookAt.new(center, endHeading, tilt, range), 2, nil, 'smooth'
      end
  end
  
  # Adds a SoundCue object.
  def sound_cue(href, ds = nil)
      Kamelopard::SoundCue.new href, ds
  end
  
  # XXX This implementation of orbit is trying to do things the hard way, but the code might be useful for other situations where the hard way is the only possible one
  # def orbit(center, range = 100, startHeading = 0, endHeading = 360)
  #     p = ThreeDPointList.new()
  # 
  #     # Figure out how far we're going, and d
  #     dist = endHeading - startHeading
  # 
  #     # We want at least 5 points (arbitrarily chosen value), plus at least 5 for each full revolution
  #     step = (endHeading - startHeading) / ((endHeading - startHeading) / 360.0).to_i * 5 + 5
  #     startHeading.step(endHeading, step) do |theta|
  #         p << KMLPoint.new(
  #             center.longitude + Math.cos(theta), 
  #             center.latitude + Math.sin(theta), 
  #             center.altitude, center.altitudeMode)
  #     end
  #     p << KMLPoint.new(
  #         center.longitude + Math.cos(endHeading), 
  #         center.latitude + Math.sin(endHeading), 
  #         center.altitude, center.altitudeMode)
  # 
  #     p.interpolate.each do |a|
  #         fly_to 
  #     end
  # end
  
  # Sets a prefix for all kml_id objects. Note that this does *not* change
  # previously created objects' kml_ids... just new kml_ids going forward.
  def set_prefix_to(a)
      Kamelopard.id_prefix = a
  end
  
  # Writes KML output (and if applicable, viewsyncrelay configuration) to files.
  # Include a file name for the actions_file argument to get viewsyncrelay
  # configuration output as well. Note that this configuration includes only the
  # actions section; users are responsible for creating appropriate linkages,
  # inputs and outputs, and transformations, on their own, presumably in a
  # separate file.
  def write_kml_to(file = 'doc.kml', actions_file = 'actions.yml')
      File.open(file, 'w') do |f| f.write get_kml.to_s end
      if (get_document.vsr_actions.size > 0) then
          File.open(actions_file, 'w') do |f| f.write get_document.get_actions end
      end
      #File.open(file, 'w') do |f| f.write get_kml.to_s.gsub(/balloonVis/, 'gx:balloonVis') end
  end
  
  # Fades a screen overlay in or out. The show argument is boolean; true to
  # show the overlay, or false to hide it. The fade will happen smoothly (as
  # opposed to immediately) if the options hash includes a :duration element
  # set to some positive number of seconds.
  def fade_overlay(ov, show, options = {})
      color = '00ffffff'
      color = 'ffffffff' if show
      if ov.is_a? String then
          id = ov  
      else
          id = ov.kml_id
      end
  
      a = XML::Node.new 'Change'
      b = XML::Node.new 'ScreenOverlay'
      b.attributes['targetId'] = id
      c = XML::Node.new 'color'
      c << XML::Node.new_text(color)
      b << c
      a << b
      k = Kamelopard::AnimatedUpdate.new [a], options 
  end
  
  # Given telemetry data, such as from an aircraft, including latitude,
  # longitude, and altitude, this will figure out realistic-looking tilt,
  # heading, and roll values and create a series of FlyTo objects to follow the
  # extrapolated flight path
  module TelemetryProcessor
      Pi = 3.1415926535
  
      def TelemetryProcessor.get_heading(p)
          x1, y1, x2, y2 = [ p[1][0], p[1][1], p[2][0], p[2][1] ]
  
          h = Math.atan((x2-x1) / (y2-y1)) * 180 / Pi
          h = h + 180.0 if y2 < y1
          h
      end
  
      def TelemetryProcessor.get_dist2(x1, y1, x2, y2)
          Math.sqrt( (x2 - x1)**2 + (y2 - y1)**2).abs
      end
  
      def TelemetryProcessor.get_dist3(x1, y1, z1, x2, y2, z2)
          Math.sqrt( (x2 - x1)**2 + (y2 - y1)**2 + (z2 - z1)**2 ).abs
      end
  
      def TelemetryProcessor.get_tilt(p)
          x1, y1, z1, x2, y2, z2 = [ p[1][0], p[1][1], p[1][2], p[2][0], p[2][1], p[2][2] ]
          smoothing_factor = 10.0
          dist = get_dist3(x1, y1, z1, x2, y2, z2)
          dist = dist + 1
                  # + 1 to avoid setting dist to 0, and having div-by-0 errors later
          t = Math.atan((z2 - z1) / dist) * 180 / Pi / @@options[:exaggerate]
                  # the / 2.0 is just because it looked nicer that way
          90.0 + t
      end
  
      def TelemetryProcessor.get_roll(p)
          x1, y1, x2, y2, x3, y3 = [ p[0][0], p[0][1], p[1][0], p[1][1], p[2][0], p[2][1] ]
          return 0 if x1.nil? or x2.nil?
  
          # Measure roll based on angle between P1 -> P2 and P2 -> P3. To be really
          # exact I ought to take into account altitude as well, but ... I don't want
          # to
  
          # Set x2, y2 as the origin
          xn1 = x1 - x2
          xn3 = x3 - x2
          yn1 = y1 - y2
          yn3 = y3 - y2
          
          # Use dot product to get the angle between the two segments
          angle = Math.acos( ((xn1 * xn3) + (yn1 * yn3)) / (get_dist2(0, 0, xn1, yn1).abs * get_dist2(0, 0, xn3, yn3).abs) ) * 180 / Pi
  
          @@options[:exaggerate] * (angle - 180)
      end
  
      def TelemetryProcessor.fix_coord(a)
          a = a - 360 if a > 180
          a = a + 360 if a < -180
          a
      end
  
      # This is the only function in the module that users are expected to
      # call, and even then users should probably use the tour_from_points
      # function. The p argument contains an ordered array of points, where
      # each point is represented as an array consisting of longitude,
      # latitude, and altitude, in that order. This will add a series of
      # gx:FlyTo objects following the path determined by those points.
      #--
      # XXX Have some way to adjust FlyTo duration based on the distance
      # between points, or based on user input.
      #++
      def TelemetryProcessor.add_flyto(p)
          p2 = TelemetryProcessor::normalize_points p
          p = p2
          heading = get_heading p
          tilt = get_tilt p
          # roll = get_roll(last_last_lon, last_last_lat, last_lon, last_lat, lon, lat)
          roll = get_roll p
          #p = Kamelopard::Point.new last_lon, last_lat, last_alt, { :altitudeMode => :absolute }
          point = Kamelopard::Point.new p[1][0], p[1][1], p[1][2], { :altitudeMode => :absolute }
          c = Kamelopard::Camera.new point, { :heading => heading, :tilt => tilt, :roll => roll, :altitudeMode => :absolute }
          f = Kamelopard::FlyTo.new c, { :duration => @@options[:pause], :mode => :smooth }
          f.comment = "#{p[1][0]} #{p[1][1]} #{p[1][2]} to #{p[2][0]} #{p[2][1]} #{p[2][2]}"
      end
  
      def TelemetryProcessor.options=(a)
          @@options = a
      end
  
      def TelemetryProcessor.normalize_points(p)
          # The whole point here is to prevent problems when you cross the poles or the dateline
          # This could have serious problems if points are really far apart, like
          # hundreds of degrees. This seems unlikely.
          lons = ((0..2).collect { |i| p[i][0] })
          lats = ((0..2).collect { |i| p[i][1] })
  
          lon_min, lon_max = lons.minmax
          lat_min, lat_max = lats.minmax
  
          if (lon_max - lon_min).abs > 200 then
              (0..2).each do |i|
                  lons[i] += 360.0 if p[i][0] < 0
              end
          end
  
          if (lat_max - lat_min).abs > 200 then
              (0..2).each do |i|
                  lats[i] += 360.0 if p[i][1] < 0
              end
          end
  
          return [
              [ lons[0], lats[0], p[0][2] ],
              [ lons[1], lats[1], p[1][2] ],
              [ lons[2], lats[2], p[2][2] ],
          ]
      end
  end
  
  # Creates a tour from a series of points, using TelemetryProcessor::add_flyto.
  #
  # The first argument is an ordered array of points, where each point is
  # represented as an array of longitude, latitude, and altitude (in meters),
  # in that order. The only options currently recognized are :pause and
  # :exaggerate. :pause controls the flight speed by specifying the duration of
  # each FlyTo element. Its default is 1 second. There is currently no
  # mechanism for having anything other than constant durations between points.
  # :exaggerate is an numeric value that defaults to 1; when set to larger
  # values, it will exaggerate tilt and roll values, because they're sort of
  # boring at normal scale.
  def tour_from_points(points, options = {})
      options.merge!({
          :pause => 1,
          :exaggerate => 1
      }) { |key, old, new| old }
      TelemetryProcessor.options = options
      (0..(points.size-3)).each do |i|
          TelemetryProcessor::add_flyto points[i,3]
      end
  end
  
  # Given a hash of values, this creates an AbstractView object. Possible
  # values in the hash are :latitude, :longitude, :altitude, :altitudeMode,
  # :tilt, :heading, :roll, and :range. If the hash specifies :roll, a Camera
  # object will result; otherwise, a LookAt object will result. Specifying both
  # :roll and :range will still result in a Camera object, and the :range
  # option will be ignored. :roll and :range have no default; all other values
  # default to 0 except :altitudeMode, which defaults to :relativeToGround
  def make_view_from(options = {})
      o = {}
      o.merge! options
      options.each do |k, v| o[k.to_sym] = v unless k.kind_of? Symbol
      end
  
      # Set defaults
      [
          [ :altitude, 0 ],
          [ :altitudeMode, :relativeToGround ],
          [ :latitude, 0 ],
          [ :longitude, 0 ],
          [ :tilt, 0 ],
          [ :heading, 0 ],
          [ :extrude, 0 ],
      ].each do |a|
          o[a[0]] = a[1] unless o.has_key? a[0]
      end
  
      p = point o[:longitude], o[:latitude], o[:altitude], o[:altitudeMode], o[:extrude]
  
      if o.has_key? :roll then
          view = Kamelopard::Camera.new p
      else
          view = Kamelopard::LookAt.new p
      end
  
      [ :altitudeMode, :tilt, :heading, :timestamp, :timespan, :timestamp, :range, :roll, :viewerOptions ].each do |a|
          view.method("#{a.to_s}=").call(o[a]) if o.has_key? a
      end
  
      view
  end
  
  # Creates a ScreenOverlay object
  def screenoverlay(options = {})
      Kamelopard::ScreenOverlay.new options
  end
  
  # Creates an XY object, for use when building Overlay objects
  def xy(x = 0.5, y = 0.5, xt = :fraction, yt = :fraction)
      Kamelopard::XY.new x, y, xt, yt
  end
  
  # Creates an IconStyle object.
  def iconstyle(href = nil, options = {})
      Kamelopard::IconStyle.new href, options
  end
  
  # Creates an LabelStyle object.
  def labelstyle(scale = 1, options = {})
      Kamelopard::LabelStyle.new scale, options
  end
  
  # Creates an BalloonStyle object.
  def balloonstyle(text, options = {})
      Kamelopard::BalloonStyle.new text, options
  end
  
  # Creates an Style object.
  def style(options = {})
      Kamelopard::Style.new options
  end
  
  # Creates a LookAt object focused on the given point
  def look_at(point = nil, options = {})
      Kamelopard::LookAt.new point, options
  end
  
  # Creates a Camera object focused on the given point
  def camera(point = nil, options = {})
      Kamelopard::Camera.new point, options
  end
  
  # Creates a FlyTo object flying to the given AbstractView
  def fly_to(view = nil, options = {})
      Kamelopard::FlyTo.new view, options
  end
  
  # Pulls the Placemarks from the KML document d and yields each in turn to the caller
  # k = an XML::Document containing KML
  def each_placemark(d)
      i = 0
      d.find('//kml:Placemark').each do |p|
          all_values = {}
  
          # These fields are part of the abstractview
          view_fields = %w{ latitude longitude heading range tilt roll altitude altitudeMode gx:altitudeMode }
          # These are other field I'm interested in
          other_fields = %w{ description name }
          all_fields = view_fields.clone
          all_fields.concat(other_fields.clone)
          all_fields.each do |k|
              if k == 'gx:altitudeMode' then
                  ix = k
                  next unless p.find_first('kml:altitudeMode').nil?
              else
                  ix = "kml:#{k}"
              end
              r = k == "gx:altitudeMode" ? :altitudeMode : k.to_sym 
              tmp = p.find_first("descendant::#{ix}")
              next if tmp.nil?
              all_values[k == "gx:altitudeMode" ? :altitudeMode : k.to_sym ] = tmp.content
          end
          view_values = {}
          view_fields.each do |v| view_values[v.to_sym] = all_values[v.to_sym].clone if all_values.has_key? v.to_sym end
          yield make_view_from(view_values), all_values
      end
  end
  
  # Makes an HTML tour index, linked to a one-pixel screen overlay. The HTML
  # contains links to start each tour.
  def make_tour_index(erb = nil, options = {})
      get_document.make_tour_index(erb, options)
  end
  
  # Superceded by toggle_balloon_for, but retained for backward compatibility
  def show_hide_balloon(p, wait, options = {})
      show_balloon_for p, options
      pause wait
      hide_balloon_for p, options
  end
  
  # Creates a CDATA XML::Node. This is useful for, among other things,
  # ExtendedData values
  def cdata(text)
      XML::Node.new_cdata text.to_s
  end
  
  # Returns an array of two values, equal to l +/- p%, defining a "band" around the central value l
  # NB! p is interpreted as a percentage, not a fraction. IOW the result is divided by 100.0.
  def band(l, p)
      f = l * p / 100.0
      [ l - f, l + f ]
  end
  
  
  # Ensures v is within the range [min, max]. Modifies v to be within that range,
  # assuming the number line is circular (as with latitude or longitude)
  def circ_bounds(v, max, min)
      w = max - min
      if v > max then
          while (v > max) do
              v = v - w
          end
      elsif v < min then
          while (v < min) do
              v = v + w
          end
      end
      v
  end
  
  # These functions ensure the given value is within appropriate bounds for a
  # latitude or longitude. Modifies it as necessary if it's not.
  def lat_check(l)
      circ_bounds(l * 1.0, 90.0, -90.0)
  end
  
  # See lat_check()
  def long_check(l)
      circ_bounds(l * 1.0, 180.0, -180.0)
  end

  # Turns an array of two values (min, max) into a string suitable for use as a
  # viewsyncrelay constraint
  def to_constraint(arr)
    "[#{arr[0]}, #{arr[1]}]"
  end
  
  # Adds a VSRAction object (a viewsyncrelay action) to the document, for
  # viewsyncrelay configuration
  def do_action(cmd, options = {})
    # XXX Finish this
  end

  # Returns the Document's VSRActions as a YAML string, suitable for writing to
  # a viewsyncrelay configuration file
  def get_actions
    get_document.get_actions_yaml
  end

  # Writes actions to a viewsyncrelay config file
  def write_actions_to(filename = 'actions.yml')
    File.open(filename, 'w') do |f| f.write get_actions end
  end

  def get_doc_holder
    return Kamelopard::DocumentHolder.instance
  end
