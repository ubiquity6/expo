/* @flow */

import React from 'react';
import { Animated, StyleSheet } from 'react-native';

import { SlidingTabNavigation } from '@expo/ex-navigation';

import { capitalize } from 'lodash';

export default class StyledSlidingTabNavigation extends React.Component {
  render() {
    // eslint-disable-next-line no-unused-vars
    let { keyToTitle, children, ...props } = this.props;

    return (
      <SlidingTabNavigation
        {...props}
        tabBarStyle={[styles.tabBar, props.tabBarStyle]}
        barBackgroundColor="#fff"
        position="top"
        getRenderLabel={this._getRenderLabel}
        indicatorStyle={styles.tabIndicator}
        pressColor="rgba(0,0,0,0.2)">
        {children}
      </SlidingTabNavigation>
    );
  }

  _getRenderLabel = props => scene => {
    const { route, index } = scene;

    let title;
    if (this.props.keyToTitle) {
      title = this.props.keyToTitle[route.key];
    } else {
      title = capitalize(route.key);
    }

    const selectedColor = '#0F73B6';
    const unselectedColor = 'rgba(36, 44, 58, 0.4)';
    let color;

    const inputRange = props.navigationState.routes.map((x, i) => i);
    const outputRange = inputRange.map(
      inputIndex => (inputIndex === index ? selectedColor : unselectedColor)
    );
    color = props.position.interpolate({
      inputRange,
      outputRange,
    });

    return (
      <Animated.Text style={{ color, fontWeight: '500', fontSize: 13, letterSpacing: 0.46 }}>
        {title.toUpperCase()}
      </Animated.Text>
    );
  };
}

const styles = StyleSheet.create({
  tabBar: {
    elevation: 0,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(36, 44, 58, 0.06)',
  },
  tabIndicator: {
    backgroundColor: '#0F73B6',
  },
});
