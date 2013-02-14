# vim:ts=4:sw=4:et:smartindent:nowrap

$LOAD_PATH << './lib'
require 'kamelopard'
require "xml"
require 'tempfile'

Kamelopard.set_logger lambda { |lev, mod, msg|
    STDERR.puts "#{lev} #{mod}: #{msg}"
}

# Printing debug information.
def put_info(str)
    puts
    puts "="*60
    puts str
    puts "*"*60
end

#
# Returns the first node found in given doc using given xpath.
#
#
def find_first_kml(doc, xpath)
  doc.find_first xpath, "kml:http://www.opengis.net/kml/2.2"
end


#
# Returns the first node found among children with given name.
#
#
def get_child(node, name)
    a = nil
    node.children.each { |child|
        if child.name == name
            a = child
            break
        end
    }
    return a
end

#
# Returns the content of the first node found among children with given name.
#
#
def get_child_content(node, name)
    n = node.children.detect{ |child| child.name == name}
    n.content unless n.nil?
end

#
# Returns the first child with given name.
#
# On the object param there used to_kml method for getting the kml.
#
def get_obj_child(object, name)
  k = object.to_kml
  get_child(k, name)
end

#
# Returns the content of the first child with given name.
#
# On the object param there used to_kml method for getting the kml.
#
def get_obj_child_content(object, name)
  k = object.to_kml
  get_child_content(k, name)
end

#
# Builds proper kml from given node. It surrounds kml from given node with kml tag.
# This must be done for using xpath with libxml. If you want to use xpath, then the
# node need to belong to a proper libxml document, so we need a proper xml.
#
def build_doc_from_node(node)
    kml =<<XXXX
    <kml xmlns="http://www.opengis.net/kml/2.2"
    xmlns:gx="http://www.google.com/kml/ext/2.2"
    xmlns:kml="http://www.opengis.net/kml/2.2"
    xmlns:atom="http://www.w3.org/2005/Atom"
    xmlns:xal="urn:oasis:names:tc:ciq:xsdschema:xAL:2.0">
      #{node.to_kml.to_s}
    </kml>
XXXX
    doc = XML::Document.string(kml)
end


def test_lat_lon_quad(d, n)
    get_child_content(d, 'coordinates').should == "#{n},#{n} #{n},#{n} #{n},#{n} #{n},#{n}"
end

def test_lat_lon_box(l, latlon)
    get_child_content(l, 'north').should == latlon.north.to_s
    get_child_content(l, 'south').should == latlon.south.to_s
    get_child_content(l, 'east').should == latlon.east.to_s
    get_child_content(l, 'west').should == latlon.west.to_s
end

def test_lod(d, lodval)
    %w[ minLodPixels maxLodPixels minFadeExtent maxFadeExtent ].each do |f|
        get_child_content(d, "#{f}").to_i.should == lodval
    end
end

def check_kml_values(o, values)
    values.each do |k, v|
        o.method("#{k}=").call(v)
        doc = build_doc_from_node o
        found = find_first_kml doc, "//kml:#{k}"
        found.should_not be_nil
        found.content.should == v.to_s
#        get_obj_child_content(o, k).should == v.to_s
    end
end

def fields_exist(o, fields)
    fields.each do |f|
        o.should respond_to(f.to_sym)
        o.should respond_to("#{f}=".to_sym)
    end
end

def match_view_vol(x, e)
    %w[ near rightFov topFov ].each do |a|
        get_child_content(x, a).to_i.should == e
    end
    %w[ leftFov bottomFov ].each do |a|
        get_child_content(x, a).to_i.should == -e
    end
end

def match_image_pyramid(x, e)
    %w[ tileSize maxWidth maxHeight gridOrigin ].each do |a|
        get_child_content(x, a).to_i.should == e
    end
end

def validate_abstractview(k, type, point, heading, tilt, roll, range, mode)
    [
        [ k.name != type, "Wrong type #{ k.name }" ],
        [ get_child_content(k, 'longitude').to_f != point.longitude, 'Wrong longitude' ],
        [ get_child_content(k, 'longitude').to_f != point.longitude, 'Wrong longitude' ],
        [ get_child_content(k, 'latitude').to_f != point.latitude, 'Wrong latitude' ],
        [ get_child_content(k, 'altitude').to_f != point.altitude, 'Wrong altitude' ],
        [ get_child_content(k, 'heading').to_f != heading, 'Wrong heading' ],
        [ get_child_content(k, 'tilt').to_f != tilt, 'Wrong tilt' ],
        [ type == 'Kamelopard::LookAt' && get_child_content(k, 'range').to_f != range, 'Wrong range' ],
        [ type == 'Kamelopard::Camera' && get_child_content(k, 'roll').to_f != roll, 'Wrong roll' ],
        [ mode !~ /SeaFloor/ && get_child_content(k, 'altitudeMode') != mode.to_s, 'Wrong altitude mode' ],
        [ mode =~ /SeaFloor/ && get_child_content(k, 'gx:altitudeMode') != mode.to_s, 'Wrong gx:altitudeMode' ]
    ].each do |a|
        return [false, a[1]] if a[0]
    end
end

def get_test_substyles()
    i = Kamelopard::IconStyle.new({ :href => 'icon' })
    la = Kamelopard::LabelStyle.new
    lin = Kamelopard::LineStyle.new
    p = Kamelopard::PolyStyle.new
    b = Kamelopard::BalloonStyle.new({ :text => 'balloon' })
    lis = Kamelopard::ListStyle.new
    [ i, la, lin, p, b, lis ]
end

def get_test_styles()
    i, la, lin, p, b, lis = get_test_substyles()

    si = Kamelopard::Style.new({ :icon => i })
    sl = Kamelopard::Style.new({
        :icon => i,
        :label => la,
        :line => lin,
        :poly => p,
        :balloon => b,
        :list => lis
    })
    sm = Kamelopard::StyleMap.new( { :icon => si, :list => sl } )

    si.kml_id = 'icon'
    sl.kml_id = 'list'
    sm.kml_id = 'map'

    [ si, sl, sm ]
end

def check_time_primitive(set_var_lambda, get_kml_lambda, xpath)
    b = '2011-01-01'
    e = '2011-02-01'
    w = '2011-01-01'
    tn = Kamelopard::TimeSpan.new b, e
    tm = Kamelopard::TimeStamp.new w

    set_var_lambda.call(tn)
    d = get_kml_lambda.call

    t = get_child d, 'TimeSpan'
    get_child_content(t, 'begin').should == b
    get_child_content(t, 'end').should == e

    set_var_lambda.call(tm)
    d = get_kml_lambda.call
    t = get_child d, 'TimeStamp'
    get_child_content(t, 'when').should == w
end

def get_kml_header
    <<-header
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
    header
end

shared_examples_for 'field_producer' do
    it 'has the right attributes' do
        fields_exist @o, @fields
    end
end

shared_examples_for 'Kamelopard::Object' do
    it 'descends from Kamelopard::Object' do
        @o.kind_of?(Kamelopard::Object).should == true
    end

    it 'has an id' do
        @o.kml_id.should_not be_nil
    end

    it 'allows a comment' do
        @o.should respond_to(:comment)
        @o.should respond_to(:comment=)
    end

    it 'should put its comment in the KML' do
        @o.comment = 'Look for this string'
        k = @o.to_kml
        k.to_s.should =~ /Look for this string/
    end

    it 'should HTML escape comments' do
        @o.comment = 'Look for << this string'
        k = @o.to_kml
        k.to_s.should =~ /Look for &lt;&lt; this string/
    end

    it 'responds to master_only' do
        @o.should respond_to(:master_only)
        @o.should respond_to(:master_only=)
        @o.master_only = true
        @o.master_only = false
    end

    it 'returns KML in master mode only when master_only' do
        @o.master_only = false
        @o.to_kml.to_s.should_not == ''
        @o.master_only = true
        @o.master_only.should be_true
        @o.to_kml.to_s.should == ''
        get_document.master_mode = true
        get_document.master_mode.should be_true
        @o.to_kml.to_s.should_not == ''
        get_document.master_mode = false
        @o.to_kml.to_s.should == ''
        @o.master_only = false
    end

    it 'appends itself to arbitrary XML nodes correctly' do
        # These classes behave differently when XML::Nodes are passed to their to_kml methods
        skip = %w{Document Feature StyleSelector ColorStyle}

        if ! skip.include?(@o.class.name.gsub(/Kamelopard::/, ''))
            x = XML::Node.new 'random'
            count = x.children.size
            @o.to_kml(x)
            x.children.size.should == count + 1
        end

    end
end

shared_examples_for 'altitudeMode' do
    it 'uses the right altitudeMode element' do
        [:absolute, :clampToGround, :relativeToGround].each do |m|
            @o.altitudeMode = m
            k = @o.to_kml
            get_child_content(k, "altitudeMode").should == m.to_s
        end

        [:clampToSeaFloor, :relativeToSeaFloor].each do |m|
            @o.altitudeMode = m
            k = @o.to_kml
            get_child_content(k, "gx:altitudeMode").should == m.to_s
        end
    end
end

shared_examples_for 'KML_includes_id' do
    it 'should include the object ID in the KML' do
        d = @o.to_kml
        d.attributes['id'].should_not be_nil
    end
end

shared_examples_for 'KML_producer' do
    it 'should have a to_kml function' do
        @o.should respond_to(:to_kml)
    end

    it 'should create a XML document when to_xml is called' do
        @o.to_kml.class.to_s.should == 'LibXML::XML::Node'
    end
end

shared_examples_for 'Kamelopard::Geometry' do
    it_should_behave_like 'Kamelopard::Object'

    it 'descends from Kamelopard::Geometry' do
        @o.kind_of?(Kamelopard::Geometry).should == true
    end
end

shared_examples_for 'Kamelopard::AbstractView' do
    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'altitudeMode'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'

    it 'descends from Kamelopard::AbstractView' do
        @o.kind_of?(Kamelopard::AbstractView).should == true
    end

    it 'accepts viewer options and includes them in the KML' do
        k = @o.to_kml
        k.should_not =~ /ViewerOptions/

        @o[:streetview] = true
        @o[:sunlight] = true
        @o[:historicalimagery] = true
        doc = build_doc_from_node(@o)
        v = doc.find("//ViewerOptions | //gx:ViewerOptions")
        v.should_not be_nil
        v.find(".//gx:option[@name='sunlight',@enabled='true']").should_not be_nil
        v.find(".//gx:option[@name='streetview',@enabled='true']").should_not be_nil
        v.find(".//gx:option[@name='historicalimagery',@enabled='true']").should_not be_nil

        @o[:streetview] = false
        @o[:sunlight] = false
        @o[:historicalimagery] = false
        doc = build_doc_from_node(@o)
        v = doc.find("//ViewerOptions | //gx:ViewerOptions")
        v.should_not be_nil
        v.find(".//gx:option[@name='sunlight',@enabled='true']").should_not be_nil
        v.find(".//gx:option[@name='streetview',@enabled='true']").should_not be_nil
        v.find(".//gx:option[@name='historicalimagery',@enabled='true']").should_not be_nil
    end

    it 'whines when a strange option is provided' do
        lambda { @o[:something_strange] = true }.should raise_exception
        lambda { @o[:streetview] = true }.should_not raise_exception
        lambda { @o[:sunlight] = true }.should_not raise_exception
        lambda { @o[:historicalimagery] = true }.should_not raise_exception
    end
end

shared_examples_for 'Kamelopard::CoordinateList' do
    it 'returns coordinates in its KML' do
        @o << [[1,2,3], [2,3,4], [3,4,5]]
        k = @o.to_kml
        e = get_child(k, 'coordinates')
        #e = k.elements['//coordinates']
        #e = k.root if e.nil?
        e = k if e.nil?

        e.should_not be_nil
        e.name.should == 'coordinates'
        e.content.should =~ /1.0,2.0,3.0/
        e.content.should =~ /2.0,3.0,4.0/
        e.content.should =~ /3.0,4.0,5.0/
    end

    describe 'when adding elements' do
        it 'accepts arrays of arrays' do
            @o << [[1,2,3], [2,3,4], [3,4,5]]
        end

        it 'accepts Kamelopard::Points' do
            @o << Kamelopard::Point.new( 3, 2, 1 )
        end

        it 'accepts arrays of points' do
            q = []
            [[1,2,3], [2,3,4], [3,4,5]].each do |a|
                q << Kamelopard::Point.new(a[0], a[1], a[2])
            end
            @o << q
        end

        it 'accepts another Kamelopard::CoordinateList' do
            p = Kamelopard::LinearRing.new([[1,2,3], [2,3,4], [3,4,5]])
            @o << p.coordinates
        end

        it 'complains when trying to add something weird' do
            a = 42
            lambda { @o << a }.should raise_error
        end
    end

end

shared_examples_for 'Kamelopard::Camera-like' do
    it_should_behave_like 'Kamelopard::AbstractView'

    it 'has the right attributes' do
        fields = %w[ timestamp timespan viewerOptions longitude latitude altitude heading tilt roll altitudeMode ]
        fields_exist @o, fields
    end

    it 'contains the right KML attributes' do
        @o.heading = 12
        @o.tilt = 12
        get_obj_child(@o, 'longitude').should_not be_nil
        get_obj_child(@o, 'latitude').should_not be_nil
        get_obj_child(@o, 'altitude').should_not be_nil
        get_obj_child(@o, 'heading').should_not be_nil
        get_obj_child(@o, 'tilt').should_not be_nil
    end
end

shared_examples_for "Kamelopard::TimePrimitive" do
    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'KML_includes_id'

    it 'descends from Kamelopard::TimePrimitive' do
        @o.kind_of?(Kamelopard::TimePrimitive).should == true
    end
end

shared_examples_for 'Kamelopard::Feature' do
    def document_has_styles(d)
        doc = build_doc_from_node d

        si = find_first_kml doc, "//kml:Style[@id='icon']"
        raise 'Could not find iconstyle' if si.nil?

        sl = find_first_kml doc, "//kml:Style[@id='list']"
        raise 'Could not find liststyle' if sl.nil?

        sm = find_first_kml doc, "//kml:StyleMap[@id='map']"
        raise 'Could not find stylemap' if sm.nil?

        si = find_first_kml doc, "//kml:StyleMap/kml:Pair/kml:Style[@id='icon']"
        raise 'Could not find iconstyle in stylemap' if si.nil?

        sl = find_first_kml doc, '//kml:StyleMap/kml:Pair/kml:Style[@id="list"]'
        raise 'Could not find liststyle in stylemap' if sl.nil?
        true
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'

    it 'descends from Kamelopard::Feature' do
        @o.kind_of?(Kamelopard::Feature).should == true
    end

    it 'has the right attributes' do
        fields = %w[
            visibility open atom_author atom_link name
            phoneNumber snippet_text maxLines description abstractView
            timestamp timespan styleUrl styleSelector region metadata
            extendedData styles
        ]
        fields_exist @o, fields

        @o.should respond_to(:addressDetails)
    end

    it 'handles extended data correctly' do
        ed = []
        {
            'foo' => 'bar',
            'baz' => 'qux'
        }.each do |k, v|
            ed << Kamelopard::Data.new(k, v)
        end
        @o.extendedData = ed
    end

    it 'handles show and hide methods correctly' do
        @o.hide
        get_obj_child_content(@o, 'visibility').to_i.should == 0
        @o.show
        get_obj_child_content(@o, 'visibility').to_i.should == 1
    end

    it 'handles extended address stuff correctly' do
        @o.addressDetails = 'These are some extended details'
        k = Kamelopard::DocumentHolder.instance.current_document.get_kml_document
        k.root['xmlns:xal'].should == 'urn:oasis:names:tc:ciq:xsdschema:xAL:2.0'
        get_obj_child_content(@o, 'xal:AddressDetails').should == @o.addressDetails
    end

    it 'handles styles correctly' do
        get_test_styles().each do |s|
            @o.styleUrl = s
            get_obj_child_content(@o, 'styleUrl').should == "##{s.kml_id}"
        end
        @o.styleUrl = '#random'
        get_obj_child_content(@o, 'styleUrl').should == "#random"
    end

    it 'returns style KML correctly' do
        get_test_styles().each do |s|
            @o.styles << s
        end

        header = get_kml_header

        document_has_styles(@o).should == true
    end

    it 'returns the right KML for simple fields' do
        marker = 'Look for this string'
        fields = %w( name address phoneNumber description styleUrl )
        fields.each do |f|
            p = Kamelopard::Feature.new
            Kamelopard::DocumentHolder.instance.current_document.folder << p
            p.instance_variable_set("@#{f}".to_sym, marker)
            e = get_obj_child p, "#{f}"
            e.should_not be_nil
            e.content.should == marker
        end
    end

    it 'returns the right KML for more complex fields' do
        marker = 'Look for this string'
        [
            [ :@addressDetails, 'xal:AddressDetails' ],
            [ :@metadata, 'Metadata' ],
            [ :@atom_link, 'atom:link' ]
        ].each do |a|
            p = Kamelopard::Feature.new
            p.instance_variable_set(a[0], marker)
            e = get_child p.to_kml, a[1]
            e.should_not be_nil
            e.content.should == marker
        end
    end
#TODO: investigate why the field atom:author is missing

    it 'correctly KML-ifies the atom:author field' do
        o = Kamelopard::Feature.new
        marker = 'Look for this text'
        o.atom_author = marker
        doc = build_doc_from_node o
        doc.find_first('//atom:author/atom:name').content.should == marker
    end

    it 'returns the right KML for boolean fields' do
        %w( visibility open ).each do |k|
            [false, true].each do |v|
                o = Kamelopard::Feature.new
                o.instance_variable_set("@#{k}".to_sym, v)
                get_obj_child_content(o, "#{k}").to_i.should == (v ? 1 : 0)
            end
        end
    end

    it 'correctly KML\'s the Kamelopard::Snippet' do
        maxLines = 2
        text = "This is my snippet\nIt's more than two lines long.\nNo, really."

        @o.maxLines = maxLines
        @o.snippet_text  = text
        doc = build_doc_from_node @o
        s = doc.find_first("//kml:Snippet[@maxLines='#{maxLines}']", 'kml:http://www.opengis.net/kml/2.2')
        s.should_not be_nil
        s.content.should == text
    end

    describe 'correctly produces Kamelopard::Region KML' do
        before(:all) do
            @o = Kamelopard::Feature.new({ :name => 'my feature' })
            @latlon = Kamelopard::LatLonBox.new( 1, -1, 1, -1, 10 )
            @lod = Kamelopard::Lod.new(128, 1024, 128, 128)
            @r = Kamelopard::Region.new({ :latlonaltbox => @latlon, :lod => @lod })
            @o.region = @r

            @reg = get_obj_child(@o, 'Region')
            @l = get_child(@reg, 'LatLonAltBox')
            @ld = get_child(@reg, 'Lod')
        end

        it 'creates a Kamelopard::Region element' do
            @reg.should_not be_nil
            @reg['id'].should =~ /^Region_\d+$/
        end

        it 'creates the right LatLonAltBox' do
            @l.should_not be_nil
            test_lat_lon_box(@l, @latlon)
        end

        it 'creates the right LOD' do
            @ld.should_not be_nil
            get_child_content(@ld, 'minLodPixels'). should == @lod.minpixels.to_s
            get_child_content(@ld, 'maxLodPixels'). should == @lod.maxpixels.to_s
            get_child_content(@ld, 'minFadeExtent'). should == @lod.minfade.to_s
            get_child_content(@ld, 'maxFadeExtent'). should == @lod.maxfade.to_s
        end

    end

    it 'correctly KML\'s the Kamelopard::StyleSelector' do
        @o = Kamelopard::Feature.new({ :name => 'StyleSelector test' })
        get_test_styles.each do |s| @o.styles << s end
        document_has_styles(@o).should == true
    end

    it 'correctly KML\'s the Kamelopard::TimePrimitive' do
        @o.timeprimitive = Kamelopard::TimeStamp.new('dflkj')
        check_time_primitive(
            lambda { |t| @o.timeprimitive = t },
            lambda { @o.to_kml },
            ''
        )
    end

    it 'correctly KML\'s the Kamelopard::AbstractView' do
        long, lat, alt = 13, 12, 11
        heading, tilt, roll, range, mode = 1, 2, 3, 4, :clampToSeaFloor
        p = Kamelopard::Point.new long, lat, alt
        camera = Kamelopard::Camera.new(p, {
            :heading => heading,
            :tilt => tilt,
            :roll => roll
        })
        lookat = Kamelopard::LookAt.new(p, {
            :heading => heading,
            :tilt => tilt,
            :range => range
        })
        @o.abstractView = camera
        a = get_obj_child(@o, "Camera")
        a.should_not be_nil
        validate_abstractview(a, 'Camera', p, heading, tilt, roll, range, mode).should be_true
        @o.abstractView = lookat
        a = get_obj_child(@o, "LookAt")
        a.should_not be_nil
        validate_abstractview(a, 'LookAt', p, heading, tilt, roll, range, mode).should be_true
    end
end

shared_examples_for 'Kamelopard::Container' do
    it 'should handle <<' do
        @o.should respond_to('<<')
    end
end

shared_examples_for 'Kamelopard::ColorStyle' do
    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'

    it 'should accept only valid color modes' do
        @o.colorMode = :normal
        @o.colorMode = :random
        begin
            @o.colorMode = :something_wrong
        rescue RuntimeError => f
            q = f.to_s
        end
        q.should =~ /colorMode must be either/
    end

    it 'should allow setting and retrieving alpha, blue, green, and red' do
        a = 'ab'
        @o.alpha = a
        @o.alpha.should == a
        @o.blue = a
        @o.blue.should == a
        @o.green = a
        @o.green.should == a
        @o.red = a
        @o.red.should == a
    end

    it 'should get settings in the right order' do
        @o.alpha = 'de'
        @o.blue = 'ad'
        @o.green = 'be'
        @o.red = 'ef'
        @o.color.should == 'deadbeef'
    end

    it 'should do its KML right' do
        color = 'abcdefab'
        colorMode = :random
        @o.color = color
        @o.colorMode = colorMode
        get_obj_child_content(@o, 'color').should == color
        get_obj_child_content(@o, 'colorMode').should == colorMode.to_s
    end
end

shared_examples_for 'StyleSelector' do
    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'KML_includes_id'

    it 'should handle being attached to stuff' do
        @o.should respond_to(:attach)
        p = Kamelopard::Placemark.new({
            :geometry => Kamelopard::Point.new(123, 23),
            :name => 'test'
        })
        @o.attach(p)
        @o.attached?.should be_true
    end
end

shared_examples_for 'KML_root_name' do
    it 'should have the right namespace and root' do
        d = @o.to_kml
        if ! @ns.nil? then
            ns_url = 'http://www.google.com/kml/ext/2.2'
# TODO
# There is no add_namespace method
#            d.add_namespace @ns, ns_url
#            d.root.namespace.should == ns_url
        end
#        d.name.should == @o.class.name.gsub('Kamelopard::', '')
    end
end

shared_examples_for 'Kamelopard::TourPrimitive' do
    before(:each) do
        @ns = 'gx'
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'KML_root_name'
end

shared_examples_for 'Kamelopard::Overlay' do
    it_should_behave_like 'Kamelopard::Feature'

    it 'should have the right KML' do
        href = 'look for this href'
        drawOrder = 10
        color = 'ffffff'

        @o.href = href
        @o.drawOrder = drawOrder
        @o.color = color

        x = get_obj_child(@o, "Icon")
        get_child_content(x, "href").should == href

        get_obj_child_content(@o, "color").should == color
        get_obj_child_content(@o, "drawOrder").to_i.should == drawOrder

    end
end

describe 'Kamelopard::Point' do
    before(:each) do
        @attrs = { :lat => 12.4, :long => 34.2, :alt => 500 }
        @fields = %w[ latitude longitude altitude altitudeMode extrude ]
        @o = Kamelopard::Point.new(@attrs[:long], @attrs[:lat], @attrs[:alt])
    end

    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'Kamelopard::Geometry'
    it_should_behave_like 'field_producer'

    it 'accepts different coordinate formats' do
        coords = [ [ '123D30m12.2s S', '34D56m24.4s E' ],
                   [ '32d10\'23.10" N', -145.3487 ],
                   [ 123.5985745,      -45.32487 ] ]
        coords.each do |a|
            lambda { Kamelopard::Point.new(a[1], a[0]) }.should_not raise_error
        end
    end

#    it 'does not accept coordinates that are out of range' do
#        q = ''
#        begin
#            Kamelopard::Point.new(342.32487, 45908.123487)
#        rescue RuntimeError => f
#            q = f.to_s
#        end
#        q.should =~ /out of range/
#    end

    describe 'KML output' do
        it_should_behave_like 'KML_producer'
        it_should_behave_like 'altitudeMode'

        it 'has the right coordinates' do
            k = @o.to_kml
            get_child_content(k, 'coordinates').should == "#{ @attrs[:long] }, #{ @attrs[:lat] }, #{ @attrs[:alt] }"
        end

        it 'handles extrude properly' do
            @o.extrude = true
            k = @o.to_kml
            get_child_content(k, 'extrude').should == '1'
            @o.extrude = false
            k = @o.to_kml
            get_child_content(k, 'extrude').should == '0'
        end

        it 'provides the correct short form' do
            @o.altitudeMode = :clampToSeaFloor
            @o.extrude = 1
            k = @o.to_kml(nil, true)
            get_child_content(k, 'extrude').should be_nil
            get_child_content(k, 'altitudeMode').should be_nil
            @o.master_only = true
            get_child_content(k, 'extrude').should be_nil
            get_child_content(k, 'altitudeMode').should be_nil
            @o.master_only = false
        end
    end
end

describe 'Kamelopard::LineString' do
    before(:each) do
        @o = Kamelopard::LineString.new([ [1,2,3], [2,3,4], [3,4,5] ])
        @fields = %w[
            altitudeOffset extrude tessellate altitudeMode
            drawOrder longitude latitude altitude
        ]
    end

    it_should_behave_like 'altitudeMode'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'Kamelopard::Geometry'
    it_should_behave_like 'Kamelopard::CoordinateList'
    it_should_behave_like 'field_producer'

    it 'contains the right KML attributes' do
        @o.altitudeOffset = nil
        get_obj_child(@o, 'gx:altitudeOffset').should be_nil
        @o.altitudeOffset = 1
        get_obj_child(@o, 'gx:altitudeOffset').should_not be_nil
        @o.extrude = nil
        get_obj_child(@o, 'extrude').should be_nil
        @o.extrude = true
        get_obj_child(@o, 'extrude').should_not be_nil
        @o.tessellate = nil
        get_obj_child(@o, 'tessellate').should be_nil
        @o.tessellate = true
        get_obj_child(@o, 'tessellate').should_not be_nil
        @o.drawOrder = nil
        get_obj_child(@o, 'gx:drawOrder').should be_nil
        @o.drawOrder = true
        get_obj_child(@o, 'gx:drawOrder').should_not be_nil
    end
end

describe 'Kamelopard::LinearRing' do
    before(:each) do
        @o = Kamelopard::LinearRing.new([ [1,2,3], [2,3,4], [3,4,5] ])
        @fields = %w[ altitudeOffset extrude tessellate altitudeMode ]
    end

    it_should_behave_like 'altitudeMode'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'Kamelopard::Geometry'
    it_should_behave_like 'Kamelopard::CoordinateList'
    it_should_behave_like 'field_producer'

    it 'contains the right KML attributes' do
        @o.altitudeOffset = nil
        get_obj_child(@o, 'gx:altitudeOffset').should be_nil
        @o.altitudeOffset = 1
        get_obj_child(@o, 'gx:altitudeOffset').should_not be_nil
        @o.extrude = nil
        get_obj_child(@o, 'extrude').should be_nil
        @o.extrude = true
        get_obj_child(@o, 'extrude').should_not be_nil
        @o.tessellate = nil
        get_obj_child(@o, 'tessellate').should be_nil
        @o.tessellate = true
        get_obj_child(@o, 'tessellate').should_not be_nil
    end
end

describe 'Kamelopard::Camera' do
    before(:each) do
        @o = Kamelopard::Camera.new(
            Kamelopard::Point.new( 123, -123, 123 ),
            {
                :heading => 10,
                :tilt => 10,
                :roll => 10,
                :altitudeMode => :clampToGround
            }
        )
        @fields = [ 'roll' ]
    end

    it_should_behave_like 'Kamelopard::Camera-like'
    it_should_behave_like 'field_producer'

    it 'contains the right KML attributes' do
        @o.roll = 12
        get_obj_child_content(@o, 'roll').should == '12'
    end
end

describe 'Kamelopard::LookAt' do
    before(:each) do
        @o = Kamelopard::LookAt.new(
            Kamelopard::Point.new( 123, -123, 123 ),
            {
                :heading => 10,
                :tilt => 10,
                :range => 10,
                :altitudeMode => :clampToGround
            }
        )
        @fields = [ 'range' ]
    end

    it_should_behave_like 'Kamelopard::Camera-like'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'contains the right KML attributes' do
        @o.range = 10
        doc = build_doc_from_node @o
        doc.find('*[range=10]').should_not be_nil
    end
end

describe 'Kamelopard::TimeStamp' do
    before(:each) do
        @when = '01 Dec 1934 12:12:12 PM'
        @o = Kamelopard::TimeStamp.new @when
        @fields = [ :when ]
    end

    it_should_behave_like 'Kamelopard::TimePrimitive'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML elements' do
        doc = build_doc_from_node @o
        doc.find("//*/*[when='#{@when}']").should_not be_nil
    end

    it 'behaves correctly when to_kml() gets an XML::Node' do
        a = XML::Node.new 'testnode'
        @o.to_kml(a)
        a.children.first.name.should == 'TimeStamp'
    end

    it 'adds the correct namespace' do
        a = @o.to_kml(nil, 'test')
        a.name.should == 'test:TimeStamp'
    end
end

describe 'Kamelopard::TimeSpan' do
    before(:each) do
        @begin = '01 Dec 1934 12:12:12 PM'
        @end = '02 Dec 1934 12:12:12 PM'
        @o = Kamelopard::TimeSpan.new({ :begin => @begin, :end => @end })
        @fields = %w[ begin end ]
    end

    it_should_behave_like 'Kamelopard::TimePrimitive'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML elements' do
        doc = build_doc_from_node @o
        doc.find("//*/*[begin='#{ @begin }']").should_not be_nil
        doc.find("//*/*[end='#{ @end }']").should_not be_nil
    end
end

describe 'Kamelopard::Feature' do
    before(:each) do
        @o = Kamelopard::Feature.new('Some feature')
        @fields = []
    end
    it_should_behave_like 'Kamelopard::Feature'

    it 'responds correctly when to_kml() is passed an XML::Node object' do
        a = XML::Node.new 'testnode'
        @o.to_kml(a)
        a.attributes[:id].should_not be_nil
        found = false
        a.children.each do |c|
            if c.name == 'name'
                found = true
                break
            end
        end
        found.should be_true
    end
end

describe 'Kamelopard::Container' do
    before(:each) do
        @o = Kamelopard::Container.new
    end

    it_should_behave_like 'Kamelopard::Container'
end

describe 'Kamelopard::Folder' do
    before(:each) do
        @o = Kamelopard::Folder.new('test folder')
        @fields = []
    end
    it_should_behave_like 'Kamelopard::Container'
    it_should_behave_like 'Kamelopard::Feature'
end

describe 'Kamelopard::Document' do
    before(:each) do
        @o = Kamelopard::DocumentHolder.instance.current_document
        
        # Subsequent runs seem to keep the vsr_actions from previous runs, so clear 'em
        @o.vsr_actions = []

        @lat = Kamelopard.convert_coord('10d10m10.1s N')
        @lon = Kamelopard.convert_coord('10d10m10.1s E')
        @alt = 1000
        @head = 150

        @vsractions = %w{a b c d e f}
        @vsractions.each do |a|
            Kamelopard::VSRAction.new(a, :constraints => {
                :latitude => to_constraint(band(@lat, 0.1).collect{ |l| lat_check(l) }),
                :longitude => to_constraint(band(@lon, 0.1).collect{ |l| long_check(l) }),
                :heading => to_constraint(band(@head, 1)),
                :altitude => to_constraint(band(@alt, 2))
            })
        end
    end

    it_should_behave_like 'Kamelopard::Container'
    it_should_behave_like 'Kamelopard::Feature'

    it 'accepts new viewsyncrelay actions' do
        Kamelopard::DocumentHolder.instance.current_document.vsr_actions.size.should == @vsractions.size
    end

    it 'can write its viewsyncrelay actions to a valid YAML string' do
        Kamelopard::DocumentHolder.instance.current_document.vsr_actions.size.should == @vsractions.size
        act = YAML.load(get_actions)
        act['actions'].size.should == @vsractions.size
    end

    it 'can write its viewsyncrelay actions to a file' do
        file = Tempfile.new('kamelopard_test')
        file.close
        write_actions_to file.path
        YAML.parse_file(file.path)
        file.unlink
    end

    it 'should return a tour' do
        @o.should respond_to(:tour)
        @o.tour.class.should == Kamelopard::Tour
    end

    it 'should return a folder' do
        @o.should respond_to(:folder)
        @o.folder.class.should == Kamelopard::Folder
    end

    it 'should have a get_kml_document method' do
        @o.should respond_to(:get_kml_document)
        @o.get_kml_document.class.should == LibXML::XML::Document
    end
end

describe 'Kamelopard::ColorStyle' do
    before(:each) do
        @o = Kamelopard::ColorStyle.new 'ffffffff'
    end

    it_should_behave_like 'Kamelopard::ColorStyle'
    it_should_behave_like 'KML_root_name'

    it 'should return the right KML' do
        @o.color = 'deadbeef'
        @o.colorMode = :random
        get_obj_child_content(@o, 'color').should == 'deadbeef'
        get_obj_child_content(@o, 'colorMode').should == 'random'
    end

    it 'responds correctly when to_kml() is passed an XML::Node object' do
        a = XML::Node.new 'testnode'
        @o.to_kml(a)
        a.attributes[:id].should_not be_nil
        a.children.size.should == 2

        sums = {
            :color => 0,
            :colorMode => 0,
        }
        a.children.each do |c|
            sums[c.name.to_sym] += 1
        end
        sums.keys.each do |k|
            sums[k].should == 1
        end
    end
end

describe 'Kamelopard::BalloonStyle' do
    before(:each) do
        @o = Kamelopard::BalloonStyle.new 'balloon text'
        @o.textColor = 'deadbeef'
        @o.bgColor = 'deadbeef'
        @o.displayMode = :hide
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'KML_root_name'

    it 'should have the right attributes' do
        @o.bgColor.should == 'deadbeef'
        @o.textColor.should == 'deadbeef'
        @o.displayMode.should == :hide
    end

    it 'should return the right KML' do
        get_obj_child_content(@o, 'text').should == 'balloon text'
        get_obj_child_content(@o, 'bgColor').should == 'deadbeef'
        get_obj_child_content(@o, 'textColor').should == 'deadbeef'
        get_obj_child_content(@o, 'displayMode').should == 'hide'
    end
end

describe 'Kamelopard::XY' do
    before(:each) do
        @x, @y, @xunits, @yunits = 0.2, 13, :fraction, :pixels
        @o = Kamelopard::XY.new @x, @y, @xunits, @yunits
    end

    it 'should return the right KML' do
        d = @o.to_kml 'test'
        d.name = 'test'
        d.attributes['x'].to_f.should == @x
        d.attributes['y'].to_f.should == @y
        d.attributes['xunits'].to_sym.should == @xunits
        d.attributes['yunits'].to_sym.should == @yunits
    end
end

shared_examples_for 'Kamelopard::Icon' do
    before(:each) do
        @href = 'icon href'
        @values = {
            'href' => @href,
            'x' => 1.0,
            'y' => 2.0,
            'w' => 3.0,
            'h' => 4.0,
            'refreshMode' => :onInterval,
            'refreshInterval' => 4,
            'viewRefreshMode' => :onStop,
            'viewRefreshTime' => 4,
            'viewBoundScale' => 1,
            'viewFormat' => 'format',
            'httpQuery' => 'query'
        }
        @fields = @values.keys
    end

    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'

    it 'puts the right fields in KML' do
        @values.each do |f, v|
            @o.method("#{f.to_s}=".to_sym).call(v)
            kml = @o.to_kml
            d = get_obj_child(kml, 'Icon')
            elem = f
            if f == 'x' || f == 'y' || f == 'w' || f == 'h' then
                elem = 'gx:' + f
            end
            #e = d.elements["//#{elem}"]
            e = get_child d, elem
            e.should_not be_nil
            e.content.should == v.to_s
        end
    end
end

describe 'Kamelopard::IconStyle' do
    before(:each) do
        @href = 'Kamelopard::IconStyle href'
        @scale = 1.0
        @heading = 2.0
        @hs_x = 0.4
        @hs_y = 0.6
        @hs_xunits = :fraction
        @hs_yunits = :pixels
        @color = 'abcdefab'
        @colorMode = :random
        @o = Kamelopard::IconStyle.new( @href, {
            :scale => @scale,
            :heading => @heading,
            :hs_x => @hs_x,
            :hs_y => @hs_y,
            :hs_xunits => @hs_xunits,
            :hs_yunits => @hs_yunits,
            :color => @color,
            :colorMode => @colorMode
        })
    end

    it_should_behave_like 'Kamelopard::ColorStyle'

    it 'should support the right elements' do
        @o.should respond_to(:scale)
        @o.should respond_to(:scale=)
        @o.should respond_to(:heading)
        @o.should respond_to(:heading=)
    end

    it 'should have the right KML' do
        d = @o.to_kml
        i = get_child d, "Icon"
        get_child_content(i, "href").should == @href

        get_child_content(d, "scale").should == @scale.to_s
        get_child_content(d, "heading").should == @heading.to_s

        h = get_child d, 'hotSpot'
        h.attributes['x'].should == @hs_x.to_s
        h.attributes['y'].should == @hs_y.to_s
        h.attributes['xunits'].should == @hs_xunits.to_s
        h.attributes['yunits'].should == @hs_yunits.to_s
    end
end

describe 'Kamelopard::LabelStyle' do
    before(:each) do
        @fields = %w[ scale color colorMode ]
        @scale = 2
        @color = 'abcdefab'
        @colorMode = :random
        @o = Kamelopard::LabelStyle.new( @scale, {
            :color => @color,
            :colorMode => @colorMode
        })
    end

    it_should_behave_like 'Kamelopard::ColorStyle'

    it 'should have a scale field' do
        @o.should respond_to(:scale)
        @o.should respond_to(:scale=)
        get_obj_child_content(@o, 'scale').to_i.should == @scale
    end
end

describe 'Kamelopard::LineStyle' do
    before(:each) do
        @width = 1
        @outerColor = 'aaaaaaaa'
        @outerWidth = 2
        @physicalWidth = 3
        @color = 'abcdefab'
        @colorMode = :normal
        @o = Kamelopard::LineStyle.new({
            :width => @width,
            :outerColor => @outerColor,
            :outerWidth => @outerWidth,
            :physicalWidth => @physicalWidth,
            :color => @color,
            :colorMode => @colorMode
        })
        @values = {
            'width' => @width,
            'outerColor' => @outerColor,
            'outerWidth' => @outerWidth,
            'physicalWidth' => @physicalWidth
        }
        @fields = @values.keys
    end

    it_should_behave_like 'Kamelopard::ColorStyle'
    it_should_behave_like 'field_producer'

    it 'should do its KML right' do
        @values.each do |k, v|
            @o.method("#{k}=").call(v)
            elem = (k == 'width' ? k : "gx:#{k}" )
            get_obj_child_content(@o, "#{elem}").should == v.to_s
        end
    end
end

describe 'Kamelopard::ListStyle' do
    before(:each) do
        @bgColor = 'ffffffff'
        @state = :closed
        @listItemType = :check
        @href = 'list href'
        @o = Kamelopard::ListStyle.new({
            :bgColor      => @bgColor,
            :state        => @state,
            :href         => @href,
            :listItemType => @listItemType
        })
        @fields = %w[ bgColor state listItemType href ]
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'

    it 'makes the right KML' do
        values = {
            'href' => @href,
            'state' => @state,
            'listItemType' => @listItemType,
            'bgColor' => @bgColor
        }

        check_kml_values @o, values
    end
end

describe 'Kamelopard::PolyStyle' do
    before(:each) do
        @fill = 1
        @outline = 1
        @color = 'abcdefab'
        @colorMode = :random
        @o = Kamelopard::PolyStyle.new({
            :fill      => @fill,
            :outline   => @outline,
            :color     => @color,
            :colorMode => @colorMode
        })
    end

    it_should_behave_like 'Kamelopard::ColorStyle'

    it 'should have the right fields' do
        fields = %w[ fill outline ]
        fields_exist @o, fields
    end

    it 'should do the right KML' do
        values = {
            'fill' => @fill,
            'outline' => @outline
        }
        check_kml_values @o, values
    end
end

describe 'StyleSelector' do
    before(:each) do
        @o = Kamelopard::StyleSelector.new
    end

    it_should_behave_like 'StyleSelector'

    it 'responds correctly when to_kml() is passed an XML::Node object' do
        a = XML::Node.new 'testnode'
        @o.to_kml(a)
        a.attributes[:id].should_not be_nil
    end
end

describe 'Style' do
    before(:each) do
        i, la, lin, p, b, lis = get_test_substyles
        @o = Kamelopard::Style.new({
            :icon => i,
            :label => la,
            :line => lin,
            :poly => p,
            :balloon => b,
            :list => lis
        })
    end

    it_should_behave_like 'StyleSelector'

    it 'should have the right attributes' do
        [ :icon, :label, :line, :poly, :balloon, :list ].each do |a|
            @o.should respond_to(a)
            @o.should respond_to("#{ a.to_s }=".to_sym)
        end
    end

    it 'should have the right KML bits' do
        d = @o.to_kml
        %w[ IconStyle LabelStyle LineStyle PolyStyle BalloonStyle ListStyle ].each do |e|
            get_child(d, e).should_not be_nil
        end
    end
end

describe 'StyleMap' do
    def has_correct_stylemap_kml?(o)
        doc = build_doc_from_node o
        f = find_first_kml doc, '//kml:StyleMap/kml:Pair[kml:key="normal"]/kml:Style'
        s = find_first_kml doc, '//kml:StyleMap/kml:Pair[kml:key="highlight"]/kml:styleUrl'
        return f && s
    end

    before(:each) do
        i, la, lin, p, b, lis = get_test_substyles
        s = Kamelopard::Style.new({
            :icon => i,
            :balloon => b,
            :list => lis
        })
        @o = Kamelopard::StyleMap.new({ 'normal' => s, 'highlight' => 'someUrl' })
    end

    it_should_behave_like 'StyleSelector'

    it 'should handle styles vs. styleurls correctly' do
        has_correct_stylemap_kml?(@o).should be_true
    end

    it 'should merge right' do
        o = Kamelopard::StyleMap.new({ 'normal' => Kamelopard::Style.new })
        o.merge( { 'highlight' => 'test2' } )
        has_correct_stylemap_kml?(o).should be_true
    end
end

describe 'Kamelopard::Placemark' do
    before(:each) do
        @p = Kamelopard::Point.new( 123, 123 )
        @o = Kamelopard::Placemark.new({
            :name => 'placemark',
            :geometry => @p
        })
    end

    it_should_behave_like 'Kamelopard::Feature'

    it 'supports the right attributes' do
        [
            :latitude,
            :longitude,
            :altitude,
            :altitudeMode
        ].each do |f|
            @o.should respond_to(f)
        end
    end

    it 'handles returning point correctly' do
        o1 = Kamelopard::Placemark.new( 'non-point', {
            :geometry => Kamelopard::Object.new
        })
        o2 = Kamelopard::Placemark.new( 'point', {
            :geometry => Kamelopard::Point.new(123, 123)
        })

        lambda { o1.point }.should raise_exception
        lambda { o2.point }.should_not raise_exception
    end
end

describe 'Kamelopard::FlyTo' do
    before(:each) do
        @o = Kamelopard::FlyTo.new
    end

    it_should_behave_like 'Kamelopard::TourPrimitive'

    it 'puts the right stuff in the KML' do
        duration = 10
        mode = :smooth
        @o.duration = duration
        @o.mode = mode
        get_child_content(@o.to_kml, "gx:duration").should == duration.to_s
        get_child_content(@o.to_kml, "gx:flyToMode").should == mode.to_s
    end

    it 'handles Kamelopard::AbstractView correctly' do
        o = Kamelopard::FlyTo.new Kamelopard::LookAt.new( Kamelopard::Point.new(100, 100) )
        o.view.class.should == Kamelopard::LookAt
        o = Kamelopard::FlyTo.new Kamelopard::Point.new(90, 90)
        o.view.class.should == Kamelopard::LookAt
        o = Kamelopard::FlyTo.new Kamelopard::Camera.new(Kamelopard::Point.new(90, 90))
        o.view.class.should == Kamelopard::Camera
    end
end

describe 'Kamelopard::AnimatedUpdate' do
    before(:each) do
        @duration = 10
        @target = 'abcd'
        @delayedstart = 10
        @o = Kamelopard::AnimatedUpdate.new([], {
            :duration => @duration, :target => @target, :delayedStart => @delayedstart
        })
    end

    it_should_behave_like 'Kamelopard::TourPrimitive'

    it 'allows adding updates' do
        @o.updates.size.should == 0
        @o << '<Change><Placemark targetId="1"><visibility>1</visibility></Placemark></Change>'
        @o << '<Change><Placemark targetId="2"><visibility>0</visibility></Placemark></Change>'
        @o.updates.size.should == 2
    end

    it 'returns the right KML' do
        @o.is_a?(Kamelopard::AnimatedUpdate).should == true
        @o << '<Change><Placemark targetId="1"><visibility>1</visibility></Placemark></Change>'
        d = @o.to_kml
        doc = build_doc_from_node @o
        find_first_kml(doc, "//kml:Update/kml:targetHref").content.should == @target
        find_first_kml(doc, "//kml:Update/kml:Change/kml:Placemark").should_not be_nil
        get_child_content(d, "gx:delayedStart").should == @delayedstart.to_s
        get_child_content(d, "gx:duration").should == @duration.to_s


#        d.elements['//Update/targetHref'].text.should == @target
#        d.elements['//Update/Change/Placemark'].should_not be_nil
#        d.elements['//gx:delayedStart'].text.to_i.should == @delayedstart
#        d.elements['//gx:duration'].text.to_i.should == @duration
    end
end

describe 'Kamelopard::TourControl' do
    before(:each) do
        @o = Kamelopard::TourControl.new
    end

    it_should_behave_like 'Kamelopard::TourPrimitive'

    it 'should have the right KML' do
        get_obj_child_content(@o, "gx:playMode").should == 'pause'
    end
end

describe 'Kamelopard::Wait' do
    before(:each) do
        @pause = 10
        @o = Kamelopard::Wait.new(@pause)
    end

    it_should_behave_like 'Kamelopard::TourPrimitive'

    it 'should have the right KML' do
        get_obj_child_content(@o, "gx:duration").to_i.should == @pause
    end
end

describe 'Kamelopard::SoundCue' do
    before(:each) do
        @href = 'href'
        @delayedStart = 10.0
        @o = Kamelopard::SoundCue.new @href, @delayedStart
    end

    it_should_behave_like 'Kamelopard::TourPrimitive'

    it 'should have the right KML' do
        d = @o.to_kml
        get_obj_child_content(@o, "href").should == @href
        get_obj_child_content(@o, "gx:delayedStart").to_f.should == @delayedStart
    end
end

describe 'Kamelopard::Tour' do
    before(:each) do
        @name = 'TourName'
        @description = 'TourDescription'
        @o = Kamelopard::Tour.new @name, @description
        @ns = 'gx'
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_includes_id'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        Kamelopard::Wait.new
        Kamelopard::Wait.new
        Kamelopard::Wait.new
        Kamelopard::Wait.new

        get_obj_child_content(@o, "name").should == @name
        get_obj_child_content(@o, "description").should == @description

        playlist = get_obj_child(@o, "gx:Playlist")
        playlist.should_not be_nil

        # There are five waits here, because Kamelopard includes one wait at
        # the beginning of each tour automatically
        playlist.children.length.should == 5
    end
end

describe 'Kamelopard::ScreenOverlay' do
    before(:each) do
        @x = 10
        @un = :pixel
        @xy = Kamelopard::XY.new @x, @x, @un, @un
        @rotation = 10
        @name = 'some name'
        @o = Kamelopard::ScreenOverlay.new({
            :href => 'test',
            :name => @name,
            :size => @xy,
            :rotation => @rotation,
            :overlayXY => @xy,
            :screenXY => @xy,
            :rotationXY => @xy
        })
        @fields = %w[ overlayXY screenXY rotationXY size rotation ]
    end

    it_should_behave_like 'Kamelopard::Overlay'
    it_should_behave_like 'field_producer'

    it 'has the right KML' do
        d = @o.to_kml
        get_obj_child_content(@o, "name").should == @name
        get_obj_child_content(@o, "rotation").should == @rotation.to_s
        %w[ overlayXY screenXY rotationXY size ].each do |a|
            node = get_obj_child(@o, a)
            node.attributes['x'].should == @x.to_s
            node.attributes['y'].should == @x.to_s
            node.attributes['xunits'].should == @un.to_s
            node.attributes['yunits'].should == @un.to_s

        end
    end
end

shared_examples_for 'Kamelopard::ViewVolume' do
    before(:each) do
        @n = 53
        @fields = %w[ leftFov rightFov bottomFov topFov near ]
    end

    it_should_behave_like 'field_producer'

    it 'has the right KML' do
        @o.leftFov = -@n
        @o.rightFov = @n
        @o.bottomFov = -@n
        @o.topFov = @n
        @o.near = @n

        d = @o.to_kml
        volume = get_obj_child(@o, "ViewVolume")
        match_view_vol(volume, @n)
    end
end

shared_examples_for 'Kamelopard::ImagePyramid' do
    before(:each) do
        @fields = %w[ tileSize maxWidth maxHeight gridOrigin ]
    end

    it_should_behave_like 'field_producer'

    it 'has the right KML' do
        @o.tileSize = @n
        @o.maxWidth = @n
        @o.maxHeight = @n
        @o.gridOrigin = @n
        d = @o.to_kml
        pyramid = get_obj_child(@o, "ImagePyramid")
        match_image_pyramid(pyramid, @n)
    end
end

describe 'Kamelopard::PhotoOverlay' do
    before(:each) do
        @n = 34
        @rotation = 10
        @point = Kamelopard::Point.new(@n, @n)
        @shape = 'cylinder'
        @o = Kamelopard::PhotoOverlay.new({
            :href => 'test',
            :point => @point,
            :rotation => @rotation,
            :point => @point,
            :shape => @shape,
            :leftFov => -@n,
            :rightFov => @n,
            :bottomFov => -@n,
            :topFov => @n,
            :near => @n,
            :tileSize => @n,
            :maxWidth => @n,
            :maxHeight => @n,
            :gridOrigin => @n
        })
        @fields = %w[ rotation point shape ]
    end

    it_should_behave_like 'Kamelopard::Overlay'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'Kamelopard::ViewVolume'
    it_should_behave_like 'Kamelopard::ImagePyramid'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do

        get_obj_child_content(@o, "shape").should == @shape
        get_obj_child_content(@o, "rotation").should == @rotation.to_s


        volume = get_obj_child(@o, "ViewVolume")
        pyramid = get_obj_child(@o, "ImagePyramid")

        match_view_vol(volume, @n).should be_true
        match_image_pyramid(pyramid, @n).should be_true
    end
end

describe 'Kamelopard::LatLonBox' do
    before(:each) do
        @n = 130.2
        @o = Kamelopard::LatLonBox.new @n, @n, @n, @n, @n, @n, @n, :relativeToGround
        @fields = %w[ north south east west rotation minAltitude maxAltitude altitudeMode ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'

    it 'has the right KML in altitude mode' do
        d = @o.to_kml(nil, true)
        get_child_content(d, "minAltitude").should == @n.to_s
        get_child_content(d, "maxAltitude").should == @n.to_s
        test_lat_lon_box(d, @o)
    end

    it 'has the right KML in non-altitude mode' do
        d = @o.to_kml(nil, false)
        test_lat_lon_box(d, @o)
    end
end

describe 'Kamelopard::LatLonQuad' do
    before(:each) do
        @n = 123.2
        @p = Kamelopard::Point.new(@n, @n)
        @o = Kamelopard::LatLonQuad.new @p, @p, @p, @p
        @fields = %w[ lowerLeft lowerRight upperRight upperLeft ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'

    it 'has the right KML' do
        d = @o.to_kml
        test_lat_lon_quad(d, @n)
    end
end

describe 'Kamelopard::GroundOverlay' do
    before(:each) do
        @icon_href = 'some href'
        @n = 123.2
        @lb = Kamelopard::LatLonBox.new @n, @n, @n, @n, @n, @n, @n, :relativeToGround
        @p = Kamelopard::Point.new(@n, @n)
        @lq = Kamelopard::LatLonQuad.new @p, @p, @p, @p
        @altmode = :relativeToSeaFloor
        @o = Kamelopard::GroundOverlay.new @icon_href, { :latlonbox => @lb, :latlonquad => @lq, :altitude => @n, :altitudeMode => @altmode }
        @fields = %w[ altitude altitudeMode latlonbox latlonquad ]
    end

    it_should_behave_like 'Kamelopard::Overlay'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'altitudeMode'
    it_should_behave_like 'KML_root_name'

    it 'complains when latlonbox and latlonquad are nil' do
        o = Kamelopard::GroundOverlay.new @icon_href, { :altitude => @n, :altitudeMode => @altmode }
        lambda { o.to_kml }.should raise_exception
        o.latlonquad = @lq
        lambda { o.to_kml }.should_not raise_exception
    end

    it 'has the right KML' do
        d = @o.to_kml
        get_child_content(d, 'altitude').should == @n.to_s

        lat_lon_box = get_child d, "LatLonBox"
        test_lat_lon_box(lat_lon_box, @lb)


        lat_lon_quad = get_child d, "gx:LatLonQuad"
        test_lat_lon_quad(lat_lon_quad, @n)
    end
end

describe 'Kamelopard::Lod' do
    before(:each) do
        @n = 324
        @o = Kamelopard::Lod.new @n, @n, @n, @n
        @fields = %w[ minpixels maxpixels minfade maxfade ]
    end

    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        d = @o.to_kml
        test_lod d, @n
    end
end

describe 'Kamelopard::Region' do
    before(:each) do
        @n = 12
        @lb = Kamelopard::LatLonBox.new @n, @n, @n, @n, @n, @n, @n, :relativeToGround
        @ld = Kamelopard::Lod.new @n, @n, @n, @n
        @o = Kamelopard::Region.new({ :latlonaltbox => @lb, :lod => @ld })
        @fields = %w[ latlonaltbox lod ]
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        d = @o.to_kml
        test_lat_lon_box(get_child(d, 'LatLonAltBox'), @lb)
        test_lod(get_child(d, 'Lod'), @n)
    end
end

describe 'Kamelopard::Orientation' do
    before(:each) do
        @n = 37
        @o = Kamelopard::Orientation.new @n, @n, @n
        @fields = %w[ heading tilt roll ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

#    it 'should complain with weird arguments' do
#        lambda { Kamelopard::Orientation.new -1, @n, @n }.should raise_exception
#        lambda { Kamelopard::Orientation.new @n, -1, @n }.should raise_exception
#        lambda { Kamelopard::Orientation.new @n, @n, -1 }.should raise_exception
#        lambda { Kamelopard::Orientation.new 483, @n,  @n }.should raise_exception
#        lambda { Kamelopard::Orientation.new @n,  483, @n }.should raise_exception
#        lambda { Kamelopard::Orientation.new @n,  @n,  483 }.should raise_exception
#    end

    it 'has the right KML' do
        d = @o.to_kml
        @fields.each do |f|
            get_child_content(d, f).to_i.should == @n
        end
    end
end

describe 'Kamelopard::Scale' do
    before(:each) do
        @n = 213
        @o = Kamelopard::Scale.new @n, @n, @n
        @fields = %w[ x y z ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        d = @o.to_kml
        @fields.each do |f|
            get_child_content(d, f).to_i.should == @n
        end
    end
end

describe 'Kamelopard::Alias' do
    before(:each) do
        @n = 'some href'
        @o = Kamelopard::Alias.new @n, @n
        @fields = %w[ targetHref sourceHref ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        d = @o.to_kml
        @fields.each do |f|
            get_child_content(d, "#{f}").should == @n
        end
    end
end

describe 'Kamelopard::ResourceMap' do
    before(:each) do
        targets = %w[ Neque porro quisquam est qui  dolorem     ipsum      quia dolor sit  amet consectetur adipisci velit ]
        sources = %w[ Lorem ipsum dolor    sit amet consectetur adipiscing elit Nunc  quis odio metus       Fusce    at    ]
        @aliases = []
        targets.zip(sources).each do |a|
            @aliases << Kamelopard::Alias.new(a[0], a[1])
        end
        @o = Kamelopard::ResourceMap.new @aliases
        @fields = [ 'aliases' ]
    end

    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'accepts various aliases correctly' do
        # ResourceMap should accept its initializer's alias argument either as
        # an array of Alias object, or as a single Alias object. The
        # before(:each) block tests the former, and this test the latter
        o = Kamelopard::ResourceMap.new Kamelopard::Alias.new('test', 'test')
        o.aliases.size.should == 1
        @o.aliases.size.should == @aliases.size
    end

    it 'has the right KML' do
        # Make this a REXML::Document instead of just a collection of elements, for better XPath support
        doc = build_doc_from_node @o

        @aliases.each do |a|
            find_first_kml(doc, "//kml:Alias[kml:targetHref=\"#{a.targetHref}\" and kml:sourceHref=\"#{a.sourceHref}\"]").should_not be_nil
        end
    end
end

describe 'Kamelopard::Link' do
    before(:each) do
        @href = 'some href'
        @refreshMode = :onInterval
        @viewRefreshMode = :onRegion
        @o = Kamelopard::Link.new @href, { :refreshMode => @refreshMode, :viewRefreshMode => @viewRefreshMode }
        @fields = %w[ href refreshMode refreshInterval viewRefreshMode viewBoundScale viewFormat httpQuery ]
    end

    it_should_behave_like 'Kamelopard::Object'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'
    it_should_behave_like 'KML_root_name'

    it 'has the right KML' do
        @n = 213
        @o.refreshInterval = @n
        @o.viewBoundScale = @n
        @o.viewFormat = @href
        @o.httpQuery = @href
        d = @o.to_kml
        {
            :href => @href,
            :refreshMode => @refreshMode,
            :refreshInterval => @n,
            :viewRefreshMode => @viewRefreshMode,
            :viewBoundScale => @n,
            :viewFormat => @href,
            :httpQuery => @href
        }.each do |k, v|
            get_child_content(d, k.to_s).should == v.to_s
        end
    end
end

describe 'Kamelopard::Model' do
    before(:each) do
        @n = 123
        @href = 'some href'
        @refreshMode = :onInterval
        @viewRefreshMode = :onRegion
        @link = Kamelopard::Link.new @href, { :refreshMode => @refreshMode, :viewRefreshMode => @viewRefreshMode }
        @loc = Kamelopard::Point.new(@n, @n, @n)
        @orient = Kamelopard::Orientation.new @n, @n, @n
        @scale = Kamelopard::Scale.new @n, @n, @n
        targets = %w[ Neque porro quisquam est qui  dolorem     ipsum      quia dolor sit  amet consectetur adipisci velit ]
        sources = %w[ Lorem ipsum dolor    sit amet consectetur adipiscing elit Nunc  quis odio metus       Fusce    at    ]
        @aliases = []
        targets.zip(sources).each do |a|
            @aliases << Kamelopard::Alias.new(a[0], a[1])
        end
        @resmap = Kamelopard::ResourceMap.new @aliases
        @o = Kamelopard::Model.new({ :link => @link, :location => @loc, :orientation => @orient, :scale => @scale, :resourceMap => @resmap })
        @fields = %w[ link location orientation scale resourceMap ]
    end

    it_should_behave_like 'Kamelopard::Geometry'
    it_should_behave_like 'KML_producer'
    it_should_behave_like 'field_producer'

    it 'makes the right KML' do
        d = @o.to_kml
        %w[ Link Location Orientation Scale ResourceMap ].each do |f|
            get_child(d, f).should_not be_nil
        end
        %w[ longitude latitude altitude ].each do |f|
            location = get_child(d, "Location")
            location.should_not be_nil
            get_child_content(location, f).to_i.should == @n
        end
    end
end

describe 'Kamelopard::Container' do
    before(:each) do
        @o = Kamelopard::Container.new()
    end

    it_should_behave_like 'Kamelopard::Container'
end

describe 'placemark reading' do
    before(:each) do
        @s = %{<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
	<name>My Places.kml</name>
	<Style id="some_style">
		<IconStyle>
			<scale>1.1</scale>
			<Icon>
				<href>something.png</href>
			</Icon>
			<hotSpot x="20" y="2" xunits="pixels" yunits="pixels"/>
		</IconStyle>
	</Style>
	<Folder>
		<name>My Places</name>
		<open>1</open>
		<Placemark>
			<name>1</name>
			<LookAt>
				<longitude>-122.5701578349128</longitude>
				<latitude>37.83004301072002</latitude>
				<altitude>0</altitude>
				<heading>51.16129662831626</heading>
				<tilt>45.60413428326378</tilt>
				<range>292356.4207362059</range>
				<gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>
			</LookAt>
			<styleUrl>#some_style</styleUrl>
			<Point>
				<coordinates>-122.5701578349128,37.83004301072002,0</coordinates>
			</Point>
		</Placemark>
		<Placemark>
			<name>2</name>
			<LookAt>
				<longitude>-122.4831599898557</longitude>
				<latitude>37.81426712799578</latitude>
				<altitude>0</altitude>
				<heading>106.7198650112253</heading>
				<tilt>53.06224485674277</tilt>
				<range>11157.71457873637</range>
				<gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>
			</LookAt>
			<styleUrl>#some_style</styleUrl>
			<Point>
				<coordinates>-122.4831599898557,37.81426712799578,0</coordinates>
			</Point>
		</Placemark>
		<Placemark>
			<name>3</name>
			<LookAt>
				<longitude>-122.4791157460921</longitude>
				<latitude>37.82200644299443</latitude>
				<altitude>0</altitude>
				<heading>171.349340928465</heading>
				<tilt>52.66258054379743</tilt>
				<range>3481.461153245</range>
				<gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>
			</LookAt>
			<styleUrl>#some_style</styleUrl>
			<Point>
				<coordinates>-122.4791157460921,37.82200644299443,0</coordinates>
			</Point>
		</Placemark>
	</Folder>
</Document>
</kml>
}
    end

    it 'gets the right number of placemarks' do
        i = 0
        each_placemark(XML::Document.string(@s)) do |v, p|
            i += 1
        end
        i.should == 3
    end 
end

describe 'The band function' do
    it 'correctly calculates bands' do
        band(100, 20).should == [80, 120]
        band(100, 20).should_not == [70, 120]
        band(100, 20).should_not == [80, 140]
    end
end

describe 'The latitude and longitude range checker function' do
    it 'handles longitude correctly' do
        # Within range
        long_check(35).should == 35
        # At edge of range
        long_check(180).should == 180
        # Below range
        long_check(-190).should == 170
        # Above range
        long_check(200).should == -160
        # Far below range
        long_check(-980).should == 100
    end

    it 'handles latitude correctly' do
        # Within range
        lat_check(15).should == 15
        # At edge of range
        lat_check(90).should == 90
        # Below range
        lat_check(-95).should == 85
        # Above range
        lat_check(100).should == -80
        # Far below range
        lat_check(-980).should == -80
    end
end

describe 'VSRActions' do
    before(:each) do
        @action_name = 'action name'
        @action_cmd = 'ls -1'
        @latitude = 45
        @longitude = 34
        @heading = 123
        @altitude = 453

        @action = Kamelopard::VSRAction.new(@action_name, :constraints => {
                'latitude' => to_constraint(band(@latitude, 0.1).collect{ |v| lat_check(v) }),
                'longitude' => to_constraint(band(@longitude, 0.1).collect{ |v| long_check(v) }),
                'heading' => to_constraint(band(@heading, 1)),
                'altitude' => to_constraint(band(@altitude, 2))
            }, :action => @action_cmd)
    end

    describe 'make themselves into hashes. A hash' do
        before(:each) do
            @hash = @action.to_hash
        end

        it 'doesn\'t barf when created' do
            @hash.should_not be_nil
        end

        it 'contains proper constraints' do
            @hash['constraints'].should_not be_nil
            @hash['constraints']['latitude'].should_not be_nil
            %w{latitude longitude heading altitude}.each do |i|
                @hash['constraints'][i].should =~ /\[.*, .*\]/
            end
        end
    end
end

describe 'DocumentHolder' do
    it 'supports multiple documents' do
        Kamelopard::Document.new
        name_document 'First'
        i = Kamelopard::DocumentHolder.instance.document_index
        Kamelopard::Document.new
        name_document 'Second'
        j = Kamelopard::DocumentHolder.instance.document_index

        get_doc_holder.document_index = i
        get_document.name.should == 'First'
        get_doc_holder.document_index = j
        get_document.name.should == 'Second'

    end
end
