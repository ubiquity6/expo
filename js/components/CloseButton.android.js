/* @flow */

import React from 'react';
import { withNavigation } from '@expo/ex-navigation';
import { StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import Colors from '../constants/Colors';

@withNavigation
export default class CloseButton extends React.Component {
  render() {
    return (
      <TouchableOpacity
        hitSlop={{ top: 10, left: 10, right: 10, bottom: 10 }}
        onPress={this._handlePress}
        style={styles.buttonContainer}>
        <Ionicons name="md-close" size={28} color={Colors.tintColor} />
      </TouchableOpacity>
    );
  }

  _handlePress = () => {
    this.props.navigation.dismissModal();
  };
}

const styles = StyleSheet.create({
  buttonContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingLeft: 22,
    paddingTop: 3,
  },
});
