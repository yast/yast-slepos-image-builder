#! /usr/bin/perl -w
#
# File:	modules/SleposImageBuilderXml.pm
# Package:	Configuration of NLPOS Image Builder
# Summary:	XML I/O routines + main XML data structures
# Authors:	Michael G. Fritch <mgfritch@novell.com>
#
# $Id: SleposImageBuilderXml.pm,v 1.0 2006/02/27 14:56:57 mgfritch Exp $
#

package SleposImageBuilderXml;

use strict;

use YaST::YCP qw(:LOGGING sformat);
use YaPI;

textdomain("slepos-image-builder");

use XML::DOM;
use XML::XQL;
use XML::XQL::DOM;
use Data::Dumper; # Used for dumping perl data structures to the y2log

our %TYPEINFO;

my $XmlFile = '';
my ($doc);

my $XmlFileSave = '';
my $docSave = undef;# used for saving the state of a doc.

YaST::YCP::Import ("Report");

##------------------------------------------------------------------------------------------
## XML file I/O routines -------------------------------------------------------------------
##------------------------------------------------------------------------------------------

##
# Read a specified XML file into the global document stucture.
# @param string XML file to read
# @return booean true on success
BEGIN { $TYPEINFO{Read} = ["function", "boolean", "string"]; }
sub Read {
	my $self = shift;
	$XmlFile = $_[0];

	y2milestone("Reading XML file: ", $XmlFile);
	
	# Read in the values from the XML file	
	my $parser = new XML::DOM::Parser;
	$doc = $parser->parsefile ($XmlFile);

	if (defined $doc) {
		return 1;
	}
	y2error("An error occurred while reading the following XML: ", $XmlFile);
	Report->Error(sformat(__("An error occurred while reading the following XML: %1"), $XmlFile));
	return 0;
}

##
# Write the global document stucture to the globally defined XML file.
# @param string XML file to write (if empty the globally defined $XmlFile will be used)
# @return boolean true on success
BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {
	my $self = shift;
	my $param = $_[0];
	if (defined $param) {
		y2milestone("Write($param)");
		$XmlFile = $param;
	}
	else {
		y2milestone("Write()");
	}
	if (! _isDocDefined()) {
		return 0;
	}
	y2milestone("Writing XML file: ", $XmlFile);
	my $retval = $doc->printToFile ($XmlFile);
	if (! $retval) {
		y2error("An error occurred while writing the following XML: ", $XmlFile);
		Report->Error(sformat(__("An error occurred while writing the following XML: %1"), $XmlFile));
	}
	return $retval;
}


##------------------------------------------------------------------------------------------
## Various routines ---------------------------------------------------------------------
##------------------------------------------------------------------------------------------


##
# Check the global document to be sure if is defined.  If not throw warning to y2log and return false
# @return boolean true on success
sub _isDocDefined {
	if (!defined $doc) {
		y2error("Global document not defined.");
		y2error("Try using Read(<xmlfile>) to init the global document before calling this subroutine.");
		return 0;
	}
	return 1;
}


##
# Saves the doc state so another XML doc my be read in to the global structure
# Use RestoreDocState() to retrive the saved doc state.
# @return boolean true on success
BEGIN { $TYPEINFO{SaveDocState} = ["function", "boolean"]; }
sub SaveDocState {
	my $self = shift;
	y2milestone("SaveDocState()");
	$XmlFileSave = $XmlFile;
	$docSave = $doc;
	if (defined $docSave and defined $XmlFileSave) {
		return 1;
	}
	return 0;
}


##
# Restores a saved doc state.
# Use SaveDocState() to save the doc state.
# @return boolean true on success
BEGIN { $TYPEINFO{RestoreDocState} = ["function", "boolean"]; }
sub RestoreDocState {
	my $self = shift;
	y2milestone("RestoreDocState()");
	$doc->dispose();
	$doc = $docSave;
	$XmlFile = $XmlFileSave;
	if (defined $doc and $doc == $docSave and defined $XmlFile and $XmlFile eq $XmlFileSave) {
		return 1;
	}
	return 0;
}



##------------------------------------------------------------------------------------------
## Get routines ----------------------------------------------------------------------------
##------------------------------------------------------------------------------------------


##
# Returns a list of values found using a specified XQL path.
# NOTE: does not shift the values of @_.  For internal use only!
# @param string xql path
# @return list result of items found in the xql search
sub _GetValueList {
	my $path = $_[0];

	y2milestone("GetValueList($path)");

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return undef;
	}

	if (! _isDocDefined()) {
		return undef;
	}

	my @node = $doc->xql($path);

	# Convert the list into a list of strings
	my (@ycpnode);
	y2debug("\@node=", @node);
	foreach my $element (@node) {
		y2debug("element=", $element);
		y2debug("getNodeType", $element->getNodeType());
		if ($element->getNodeType() == 1) {
			#push(@ycpnode, $element->getText());
			push(@ycpnode, $element->toString());
		}
		else {
			push(@ycpnode, $element->getNodeValue());
		}
	}
	y2milestone("GetValue xql query found: ", @ycpnode);
	return @ycpnode;
}


##
# Returns a list of values found using a specified XQL path.
# @param string xql path
# @return list result of items found in the xql search
BEGIN { $TYPEINFO{GetValueList} = ["function", ["list", "string"], "string"]; }
sub GetValueList {
	my $self = shift;
	my $path = $_[0];

	y2milestone("GetValueList($path)");

	my @ycpnode = _GetValueList($path);
	if (@ycpnode) {
		return \@ycpnode;
	}
	return [];
}

##
# Returns the first string value found using a specified XQL path.
# @param string xql path
# @return first string result of the items found in the xql search
BEGIN { $TYPEINFO{GetValueString} = ["function", "string", "string"]; }
sub GetValueString {
	my $self = shift;
	my $path = $_[0];

	y2milestone("GetValueString($path)");

	my @ycpnode = _GetValueList($path);
	if (defined $ycpnode[0]) {
		return $ycpnode[0];
	}
	return "";
}


##
# Returns a map of attribute values found using a specified XQL path.
# For Example: <ImageSpec Name="minimal" Version="1.0.0"/> will return $["Name":"minimal", "Version", 1.0.0"]
# NOTE: does not shift the values of @_.  For internal use only!
# @param string xql path (should be to a element node)
# @return map result of items found in the xql search
sub _GetAttributeMap {
	my $path = $_[0];
	y2milestone("_GetAttributeMap($path)");
	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return undef;
	}
	if (! _isDocDefined()) {
		return undef;
	}

	my @node = $doc->xql($path);

	my ($ycpblock); # hash that will become a YCP map
	# Convert the list of attributes into a YCP map (hash)
	y2debug("\@node=", @node);
	foreach my $element (@node) {
		y2debug("element=", $element);
		y2debug("getNodeType", $element->getNodeType());
		my $attr_list = $element->getAttributes();
		foreach my $attr ($attr_list->getValues()) {
			my $key = $attr->getName();
			my $value = $attr->getValue();
			$ycpblock->{$key} = $value;
		}
	}
	return $ycpblock;
}



##
# Returns a map of attribute values found using a specified XQL path.
# For Example: <ImageSpec Name="minimal" Version="1.0.0"/> will return $["Name":"minimal", "Version", 1.0.0"]
# @param string xql path (should be to a element node)
# @return map result of items found in the xql search
BEGIN { $TYPEINFO{GetAttributeMap} = ["function", ["map", "string", "string"], "string"]; }
sub GetAttributeMap {
	my $self = shift;
	my $path = $_[0];

	y2milestone("GetAttributeMap($path)");

	my $ycpblock = _GetAttributeMap($path);
	y2milestone("_GetAttributeMap returned: ".Dumper($ycpblock));

	if (defined $ycpblock) {
		return $ycpblock; # found values return as a YCP map
	}
	return {}; # return an empty hash
}



## Recursively parses a node and all of its children generating a ycp map as output.
#sub _convertNodetoYCPMap {
#	y2milestone("****************************************************************");
#	my ($node) = @_;
#	y2milestone("_parseNode($node) started.");
#	my ($ycpblock);
#
#	$ycpblock->{"NodeName"} = $node->getNodeName();
#	y2milestone("NodeName: $ycpblock->{NodeName}");
#	$ycpblock->{"NodeType"} = $node->getNodeType();
#	y2milestone("NodeType: $ycpblock->{NodeType}");
#
#	$ycpblock->{"NodeValue"} = $node->getNodeValue();
#	if (defined $ycpblock->{"NodeValue"}) {
#		y2milestone("NodeValue: $ycpblock->{NodeValue}");
#	}
##	print "NodeName: " . $node->getNodeName() . "\n";
##	print "NodeType: " . $node->getNodeType() . "\n";
##	print "NodeValue: '" . $node->getNodeValue() . "'\n";
#
#	# if the node contains attributes read them in too.
#	if ($node->getNodeType() == 1) {
#		my $attrs = $node->getAttributes();
#		my (@attrnodes);
#		for my $attr ($attrs->getValues()) {
#			push(@attrnodes, _parseNode($attr));
#		}
#		$ycpblock->{"Attributes"} = \@attrnodes;
#	}
#
#	# recursively parse the child nodes.
#	my (@childnodes);
#	for my $kid ( $node->getChildNodes) {
#		push(@childnodes, _parseNode($kid));
#	}
#	$ycpblock->{"ChildNodes"} = \@childnodes;
#
#	y2milestone("_parseNode returning: $ycpblock");
#	return $ycpblock;
#}




##------------------------------------------------------------------------------------------
## Set routines ----------------------------------------------------------------------------
##------------------------------------------------------------------------------------------

##
# Set a value in the global document structure using a specified XQL path.
# NOTE: This will only work on existing nodes of a certain node type!!!  Try one of the other set methods instead.
# @param string xql path
# @param string value to set
# @return boolean true on success
BEGIN{ $TYPEINFO{SetNodeValue} = ["function", "boolean", "string", "string"]; }
sub SetNodeValue {
	my $self = shift;
	my ($path, $value) = @_;
	
	y2milestone("SetNodeValue($path, $value)");

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (!defined $value) {
		y2error("Node value not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $retval = 0;
	foreach my $element (@node) {
		y2debug("Before NodeValue: ", $element->getNodeValue());
		$retval = $element->setNodeValue($value);
		y2debug("After NodeValue: ", $element->getNodeValue());
		if (!defined $retval) {
			return 0;
		}
	}
	y2milestone("SetNodeValue returned: ".Dumper(\$retval));
	return $retval;
}


##
# Set an attribute value in the global document structure using a specified XQL path for the XML element base.
# If the value does not exist it will be created.
# Example: SetAttribute("//ImageSpecification", "SleposRelease", "9.3") will create a new attribute named SleposRelease in the element ImageSpecification
# @param string xql path to the parent node
# @param string attribute key
# @param string attribute value
# @return boolean true on success
BEGIN{ $TYPEINFO{SetAttribute} = ["function", "boolean", "string", "string", "string"]; }
sub SetAttribute {
	my $self = shift;
	my ($path, $key, $value) = @_;
	y2milestone("SetAttribute($path, $key, $value)");	

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (!defined $key) {
		y2error("Attribute key (name) parameter not specified.");
		return 0;
	}
	if (!defined $value) {
		y2error("Attribute value parameter not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $retval = 0;
	foreach my $element (@node) {
		$retval = $element->setAttribute($key, $value);
		if (!defined $retval) {
			return 0;
		}
	}
	y2milestone("SetAttribute returned: ".Dumper(\$retval)); # setAttribute returns 1 if modifying an existing attribute and undef if creating a new attribute??? how do we know if the call to setAttribute is successful???
	return $retval;
}


##
# append a specified child node to the global document
# @param xql path to the parent node
# @param child node
# @return integer 1 on success
sub _appendChildNode {
	my ($path, $newNode) = @_;
	y2milestone("_appendChildNode($path, $newNode)");
	y2debug("Appending child node: ".Dumper(\$newNode));

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (!defined $newNode) {
		y2error("Child node parameter not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $retval = undef;
	foreach my $element (@node) {
		$retval = $element->appendChild($newNode);
		if (!defined $retval) {
			return 0;
		}
	}
	if (defined $retval) {
		 return 1;
	}
	return 0;
}


##
# Set an element value in the global document structure using a specified XQL path as the base.
# @param string xql path to the parent node
# @param string element tagname value
# @return boolean true on success
BEGIN{ $TYPEINFO{SetElement} = ["function", "boolean", "string", "string"]; }
sub SetElement {
	my $self = shift;
	my ($path, $value) = @_;
	y2milestone("SetElement($path, $value)");
	if (! _isDocDefined()) {
		return 0;
	}
	my $newNode = $doc->createElement($value);
	y2debug("New Element: $newNode");
	y2debug("New Element: ".Dumper(\$newNode));
	return _appendChildNode($path, $newNode);
}


##
# Set a Text Node value in the global document structure using a specified XQL path as the base.
# @param string xql path to the parent node
# @param string text node data
# @return boolean true on success
BEGIN{ $TYPEINFO{SetTextNode} = ["function", "boolean", "string", "string"]; }
sub SetTextNode {
	my $self = shift;
	my ($path, $value) = @_;
	y2milestone("SetTextNode($path, $value)");
	if (! _isDocDefined()) {
		return 0;
	}
	my $newNode = $doc->createElement($value);
	y2debug("New TextNode: ".Dumper(\$newNode));
	return _appendChildNode($path, $newNode);
}


##
# Set a comment value in the global document structure using a specified XQL path as the base.
# @param string xql path to the parent node
# @param string comment node data
# @return boolean true on success
BEGIN{ $TYPEINFO{SetComment} = ["function", "boolean", "string", "string"]; }
sub SetComment {
	my $self = shift;
	my ($path, $value) = @_;
	y2milestone("SetComment($path, $value)");
	if (! _isDocDefined()) {
		return 0;
	}
	my $newNode = $doc->createComment($value);
	y2debug("New Comment: ".Dumper(\$newNode));
	return _appendChildNode($path, $newNode);
}


##
# Set a CDATA section value in the global document structure using a specified XQL path as the base.
# @param string xql path to the parent node
# @param string CDATA section data
# @return boolean true on success
BEGIN{ $TYPEINFO{SetCDATASection} = ["function", "boolean", "string", "string"]; }
sub SetCDATASection {
	my $self = shift;
	my ($path, $value) = @_;
	y2milestone("SetCDATASection($path, $value)");
	if (! _isDocDefined()) {
		return 0;
	}
	my $newNode = $doc->createCDATASection($value);
	y2debug("New CDATASection: ".Dumper(\$newNode));
	return _appendChildNode($path, $newNode);
}


##------------------------------------------------------------------------------------------
## Delete routines -------------------------------------------------------------------------
##------------------------------------------------------------------------------------------

##
# Remove an attribute value in the global document structure using a specified XQL path for the XML element base.
# For Example: RemoveAttribute("//ImageSpecification, "ImageName") will remove the element //ImageSpecification/@ImageName
# @param string xql path to the element node that contains the attribute (base)
# @param string attribute key (name)
# @return boolean true on success
BEGIN{ $TYPEINFO{RemoveAttribute} = ["function", "boolean", "string", "string"]; }
sub RemoveAttribute {
	my $self = shift;
	my ($path, $key) = @_;
	y2milestone("RemoveAttribute($path, $key)");	

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (!defined $key) {
		y2error("Attribute key (name) parameter not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $oldnode = undef;
	foreach my $element (@node) {
		$oldnode = $element->removeAttribute($key);
		y2debug("Removed Node: ".Dumper(\$oldnode));
		if (!defined $oldnode) {
			return 0;
		}
	}
	if (!defined $oldnode) {
		return 1;
	}
	return 0;
}


##
# Remove a specified node from the global document
# NOTE: this will not remove Attribute nodes.  See RemoveAttribute.
# @param xql path to the node
# @return boolean true on success
sub _RemoveNode {
	my $path = $_[0];
	y2milestone("_RemoveNode($path)");

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $oldnode = undef;
	foreach my $element (@node) {
		my $parent = $element->getParentNode();
		if (defined $parent) {
			y2debug("Removing node: ".Dumper(\$element));
			$oldnode = $parent->removeChild($element);
			if (!defined $oldnode) {
				return 0;
			}
		}
	}
	if (defined $oldnode) {
		 return 1;
	}
	return 0;
}


##
# Remove a specified node from the global document
# NOTE: this will not remove Attribute nodes.  See RemoveAttribute.
# @param xql path to the node
# @return boolean true on success
BEGIN{ $TYPEINFO{RemoveNode} = ["function", "boolean", "string"]; }
sub RemoveNode {
	my $self = shift;
	my $path = $_[0];
	y2milestone("RemoveNode($path)");
	return _RemoveNode($path);
}


##
# Remove a specfied element node with a specified attribute from the global document
# @param xql path to the node
# @param map of key/values pairs for the desired attributes to check in the element before removal
# @return boolean true on success
sub _RemoveNodeWithAttributeValues {
	my $path = $_[0];
	my %attrs = %{$_[1]};

	y2milestone("RemoveNode($path, %attrs)");

	if (!defined $path) {
		y2error("XQL path parameter not specified.");
		return 0;
	}
	if (! %attrs) {
		y2error("Attribute map parameter not specified.");
		return 0;
	}
	if (! _isDocDefined()) {
		return 0;
	}

	my @node = $doc->xql($path);

	my $oldnode = undef;
	foreach my $element (@node) {
		my $do_remove = 1;
		# make sure the attributes match for this element
		foreach my $key (keys %attrs) {
			if ($attrs{$key} ne $element->getAttribute($key)) {
				$do_remove = 0; # attrs don't match....should not remove element
			}
		}
		if ($do_remove) {
			# remove the element
			my $parent = $element->getParentNode();
			if (defined $parent) {
				y2debug("Removing node: ".Dumper(\$element));
				$oldnode = $parent->removeChild($element);
				if (!defined $oldnode) {
					return 0;
				}
			}
		}
	}
	if (defined $oldnode) {
		 return 1;
	}
	return 0;
}

##
# Remove a specfied element node with a specified attribute from the global document
# @param xql path to the node
# @param map of key/values pairs for the desired attributes to check in the element before removal
# @return boolean true on success
BEGIN{ $TYPEINFO{RemoveNodeWithAttributeValues} = ["function", "boolean", "string", ["map", "string", "string"]]; }
sub RemoveNodeWithAttributeValues {
	my $self = shift;
	my $path = $_[0];
	my %attrs = %{$_[1]};
	y2milestone("RemoveNodeWithAttributeValues($path, %attrs)");
	return _RemoveNodeWithAttributeValues($path, %attrs);
}



##------------------------------------------------------------------------------------------
## slepos-image-builder specific routines ---------------------------------------------------
##------------------------------------------------------------------------------------------


##
# Handle the IncludeSpecificationList (add/remove elements)
# @param list<string> of elements to add to the IncludeSpecificationList
# @param list<string> of elements to remove to the IncludeSpecificationList
# @return boolean true on success
BEGIN{ $TYPEINFO{HandleIncludeSpecificationList} = ["function", "boolean", ["list", "string"], ["list", "string"]]; }
sub HandleIncludeSpecificationList {
	my $self = shift;
	my (@add_list);
	my (@del_list);
	my $tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@add_list = @$tmpref;
	}
	$tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@del_list = @$tmpref;
	}
	
	y2milestone("HandleIncludeSpecificationList(".Dumper(\@add_list).", ".Dumper(\@del_list).")");
	my $popup_error_msg = __("A error occured while modifying the list of image addons");

	if (! _isDocDefined()) {
		Report->Error($popup_error_msg);
		return 0;
	}
	
	my $path = '/ImageSpecification/IncludeSpecificationList';
	my @node = $doc->xql($path);
	if (! @node) {
		# IncludeSpecificationList tag does not exist...must add it.
		my $newNode = $doc->createElement('IncludeSpecificationList');
		if (! _appendChildNode('/ImageSpecification', $newNode)) {
			y2error("Failed to add element $path");
			Report->Error($popup_error_msg);
			return 0;
		}
	}

	y2milestone("\@add_list=@add_list");
	y2milestone("\@del_list=@del_list");

	# Add the elements in add_list
	foreach my $add_addon (@add_list) {
		# check to make sure this element does not already exist!
		my $found = 0;
		@node = _GetValueList($path.'/IncludeSpecification/@URI');
		if (@node) {
			foreach my $tmpFoundValue (@node) {
				if ($tmpFoundValue eq $add_addon) {
					$found = 1;
				}
			}
		}
		# if the addon value is not found, add it
		if (! $found) {
			my $newNode = $doc->createElement('IncludeSpecification');
			$newNode->setAttribute('URI', $add_addon);
			y2debug("newNode: ".Dumper(\$newNode));
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add the IncludeSpecification: $add_addon");
				Report->Error($popup_error_msg);
				return 0;
			};
		}
	}
	
	# Remove the elements in del_list
	foreach my $del_addon (@del_list) {
		_RemoveNodeWithAttributeValues($path.'/IncludeSpecification', {'URI', $del_addon});
#		if (! _RemoveNodeWithAttributeValues($path, {'URI', $del_addon})) {
#			y2error("Failed to remove element with attribute $del_addon");
#			Report->Error($popup_error_msg);
#			return 0;
#		}
	}

	return 1;
}


##
# Handle the RPMSpecifications list for packages 
# that are part of a ImageClass(disto copied by POSCDTool)
# @param list<string> of elements to add to the RPMSpecifications
# @param list<string> of elements to remove to the RPMSpecifications
# @return boolean true on success
BEGIN{ $TYPEINFO{HandleRPMSpecificationsDistro} = ["function", "boolean", ["list", "string"], ["list", "string"]]; }
sub HandleRPMSpecificationsDistro {
	my $self = shift;
	my (@add_list);
	my (@del_list);
	my $tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@add_list = @$tmpref;
	}
	$tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@del_list = @$tmpref;
	}
	
	y2milestone("HandleRPMSpecificationsDistro(".Dumper(\@add_list).", ".Dumper(\@del_list).")");
	my $popup_error_msg = __("A error occured while modifying the the list of rpm packages.");

	if (! _isDocDefined()) {
		Report->Error($popup_error_msg);
		return 0;
	}
	
	my $basepath = '/ImageSpecification';
	my $path = $basepath;
	my (@node);

	# make sure all the required element nodes are present. If not, add them.
	foreach my $appendStr ('RPMSpecifications', 'RPMIncludeList', 'RPMSet', 'RPMList') {
		@node = $doc->xql($path."/".$appendStr);
		if (! @node) {
			# $appendStr tag does not exist...must add it.
			my $newNode = $doc->createElement($appendStr);
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add element node $path");
				Report->Error($popup_error_msg);
				return 0;
			}
		}
		$path = $path."/".$appendStr;
	}

	y2milestone("\@add_list=@add_list");
	y2milestone("\@del_list=@del_list");

	# Add the elements in add_list
	foreach my $add_rpm (@add_list) {
		# check to make sure this element does not already exist!
		my $found = 0;
		@node = _GetValueList($path.'/RPM/@Name');
		if (@node) {
			foreach my $tmpFoundValue (@node) {
				if ($tmpFoundValue eq $add_rpm) {
					$found = 1;
				}
			}
		}
		# if the rpm value is not found, add it
		if (! $found) {
			my $newNode = $doc->createElement('RPM');
			$newNode->setAttribute('Name', $add_rpm);
			y2debug("newNode: ".Dumper(\$newNode));
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add the RPM package: $add_rpm");
				Report->Error($popup_error_msg);
				return 0;
			};
		}
	}
	
	# Remove the elements in del_list
	foreach my $del_rpm (@del_list) {
		_RemoveNodeWithAttributeValues($path.'/RPM', {'Name', $del_rpm});
#		if (! _RemoveNodeWithAttributeValues($path, {'URI', $del_rpm})) {
#			y2error("Failed to remove element with attribute $del_rpm");
#			Report->Error($popup_error_msg);
#			return 0;
#		}
	}

	return 1;
}


##
# Handle the Explict RPMSpecifications list for packages.
# Allows access to 3rd party software in an image descr. tree.
# @param list<string> of elements to add to the ExplicitPath list
# @param list<string> of elements to remove to the ExplicitPath list
# @return boolean true on success
BEGIN{ $TYPEINFO{HandleRPMSpecificationsExplicit} = ["function", "boolean", ["list", "string"], ["list", "string"]]; }
sub HandleRPMSpecificationsExplicit {
	my $self = shift;
	my (@add_list);
	my (@del_list);
	my $tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@add_list = @$tmpref;
	}
	$tmpref = shift;
	if (ref ($tmpref) eq "ARRAY") {
		@del_list = @$tmpref;
	}
	
	y2milestone("HandleRPMSpecificationsExplicit(".Dumper(\@add_list).", ".Dumper(\@del_list).")");
	my $popup_error_msg = __("A error occured while modifying the the list of explicit rpm packages.");

	if (! _isDocDefined()) {
		Report->Error($popup_error_msg);
		return 0;
	}
	
	my $basepath = '/ImageSpecification';
	my $path = $basepath;
	my (@node);

	# make sure all the required element nodes are present. If not, add them.
	foreach my $appendStr ('RPMSpecifications', 'RPMIncludeList', 'RPMSet') {
		@node = $doc->xql($path."/".$appendStr);
		if (! @node) {
			# $appendStr tag does not exist...must add it.
			my $newNode = $doc->createElement($appendStr);
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add element node $path");
				Report->Error($popup_error_msg);
				return 0;
			}
		}
		$path = $path."/".$appendStr;
	}

	y2milestone("\@add_list=@add_list");
	y2milestone("\@del_list=@del_list");

	# Add the elements in add_list
	foreach my $add_rpm (@add_list) {
		# check to make sure this element does not already exist!
		my $found = 0;
		@node = _GetValueList($path.'/ExplicitPath/@URI');
		if (@node) {
			foreach my $tmpFoundValue (@node) {
				if ($tmpFoundValue eq $add_rpm) {
					$found = 1;
				}
			}
		}
		# if the rpm value is not found, add it
		if (! $found) {
			my $newNode = $doc->createElement('ExplicitPath');
			$newNode->setAttribute('URI', $add_rpm);
			y2debug("newNode: ".Dumper(\$newNode));
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add the ExplicitPath RPM package: $add_rpm");
				Report->Error($popup_error_msg);
				return 0;
			};
		}
	}
	
	# Remove the elements in del_list
	foreach my $del_rpm (@del_list) {
		_RemoveNodeWithAttributeValues($path.'/ExplicitPath', {'URI', $del_rpm});
#		if (! _RemoveNodeWithAttributeValues($path, {'URI', $del_rpm})) {
#			y2error("Failed to remove element with attribute $del_rpm");
#			Report->Error($popup_error_msg);
#			return 0;
#		}
	}

	return 1;
}



##
# Set the values in the UserGroupSpecifications list
# NOTE: this will delete all current user/group nodes and repalce them with the passed in settings
# @param map<string, map> of the new user and group settings
# @return boolean true on success
BEGIN{ $TYPEINFO{SetUserGroupSpecifications} = ["function", "boolean", ["map", "string", "any"]]; }
sub SetUserGroupSpecifications {
	my $self = shift;
	my %data = %{$_[0]};
	
	y2milestone("SetUserGroupSpecifications(".Dumper(\%data).")");
	my $popup_error_msg = __("A error occured while modifying the the user and group settings.");

	if (! _isDocDefined()) {
		Report->Error($popup_error_msg);
		return 0;
	}
	
	my $basepath = '/ImageSpecification';
	my $path = $basepath;
	my (@node);


	# Remove all the elements...they are being replaced!
	_RemoveNode($path.'/UserGroupSpecifications');
#	if (! _RemoveNode($path.'/UserGroupSpecifications')) {
#		y2error("Failed to remove element ".$path.'/UserGroupSpecifications');
#		Report->Error($popup_error_msg);
#		return 0;
#	}


#FIXME: must handle the RootUser settings in a special way!!!!

	# make sure all the required element nodes are present. If not, add them.
	foreach my $appendStr ('UserGroupSpecifications', 'UserList') {
		@node = $doc->xql($path."/".$appendStr);
		if (! @node) {
			# $appendStr tag does not exist...must add it.
			my $newNode = $doc->createElement($appendStr);
			if (! _appendChildNode($path, $newNode)) {
				y2error("Failed to add element node $path");
				Report->Error($popup_error_msg);
				return 0;
			}
		}
		$path = $path."/".$appendStr;
	}


#FIXME: must add support for modifying group settings!!!!

	y2milestone("\%data=%data");

	y2milestone("data->users=".Dumper($data{'users'}));

	# Add the user elements
#	my @users_list = $data{'users'};
#	y2milestone("users_list=".Dumper(\@users_list));
	my $user_data = {};
	for $user_data (@{$data{'users'}}) {
#		y2milestone("user_data_ptr=".Dumper($user_data_ptr));
#		my %user_data = $user_data_ptr;
		#my %user_data = %{$_};
		y2milestone("************************************************************");
		y2milestone("************************************************************");
		y2milestone("************************************************************");
		y2milestone("user_data=".Dumper($user_data));
		y2milestone("************************************************************");
		y2milestone("************************************************************");
		y2milestone("************************************************************");
		# check to make sure this element does not already exist!
		my $found = 0;
		@node = _GetValueList($path.'/User/@UserId');
		if (@node) {
			foreach my $tmpFoundValue (@node) {
				if ($tmpFoundValue eq $user_data->{"uid"}) {
					$found = 1;
				}
			}
		}
		# if the user value is not found, add it
		if (! $found) {
			my $newNode = $doc->createElement('User');
			$newNode->setAttribute('UserId', $user_data->{"uid"});
			$newNode->setAttribute('Name', $user_data->{"username"});
			$newNode->setAttribute('HasPassword', "true");
			$newNode->setAttribute('EncryptedPassword', $user_data->{"user_password"});
			#FIXME: add group data here!!!!!!!!!!
			y2debug("newNode: ".Dumper(\$newNode));
			if (! _appendChildNode($path, $newNode)) {
				#y2error("Failed to add the user: ".Dumper(\%user_data));
				Report->Error($popup_error_msg);
				return 0;
			};
		}
	}




	return 1;
}




#$[
#        "groups":[
#                $["groupname":"video", "userlist":"slepos"],
#                $["groupname":"audio", "userlist":"slepos"],
#                $["groupname":"dialout", "userlist":"slepos"],
#                $["groupname":"uucp", "userlist":"slepos"]
#        ],
#        "user_defaults":$["expire":"", "group":"100", "groups":"dialout,uucp,video,audio", "home":"/home", "inactive":"-1", "shell":"/bin/bash", "skel":"/etc/skel"],
#        "users":[
#                $[
#                        "encrypted":true,
#                        "fullname":"",
#                        "gid":"100",
#                        "home":"/home/slepos",
#                        "shell":"/bin/bash",
#                        "uid":"1001",
#                        "user_password":"ta0MTYSCs3MSM",
#                        "username":"slepos"
#                ]
#        ]
#]




##
# Get the values in the UserGroupSpecifications list
# @return map of user/group settings
BEGIN{ $TYPEINFO{GetUserGroupSpecifications} = ["function", ["map", "string", "any"]]; }
sub GetUserGroupSpecifications {
	my $self = shift;
	my $data = {};
	
	y2milestone("GetUserGroupSpecifications()");
	my $popup_error_msg = __("A error occured while reading the the user and group settings.");

	if (! _isDocDefined()) {
		Report->Error($popup_error_msg);
		return 0;
	}
	
	my $path = '/ImageSpecification/UserGroupSpecifications';
	my (@node);

	# Get the user settings
	@node = $doc->xql($path."/UserList/User");
	y2debug("\@node=", @node);
	my (@users_list);
	foreach my $element (@node) {
		y2milestone("element=", $element);
		y2milestone("getNodeType", $element->getNodeType());
		if ($element->getNodeType() == 1) {
			y2milestone("elementTag=", $element->getTagName);
			if ($element->getTagName() eq "User") {
				my $ycpblock = {}; # hash that will become a YCP map
				# Get the attributes for this user element
				$ycpblock->{"user_password"} = $element->getAttribute("EncryptedPassword");
				$ycpblock->{"encrypted"} = 1;
				#$ycpblock->{"HasPassword"} = $element->getAttribute("HasPassword");  #FIXME: this doesn't match up to anything in the returned map
				$ycpblock->{"username"} = $element->getAttribute("Name");
				$ycpblock->{"uid"} = $element->getAttribute("UserId");
				# FIXME:Get the group assosiations for this element
				y2milestone("Adding new user: ".Dumper($ycpblock));
				push(@users_list, $ycpblock);
			}
		}
	}
	
	# Get the root settings
	my $root_settings = _GetAttributeMap($path."/RootSettings");
	y2milestone("root_settings=".Dumper($root_settings));
	if (defined $root_settings) {
		my $ycpblock = {};
		$ycpblock->{"uid"} = '0';
		$ycpblock->{"username"} = 'root';
		$ycpblock->{"user_password"} = $root_settings->{"EncryptedRootPassword"};
		$ycpblock->{"inactive"} = $root_settings->{"DisableRootAccess"};
		push(@users_list, $ycpblock);
	}

	# Add the users list to the YCP map
	y2milestone("users_list: ".Dumper(\@users_list));
	$data->{"users"} = [ @users_list ];



	# FIXME: must add group settings


	y2milestone("GetUserGroupSpecifications returned: ".Dumper($data));
	return $data;
}



1 # NOTE: this value (1) is required when writing a YaST perl module!
# EOF
