/* @flow */

import React from 'react';
import {
  Alert,
  NativeModules,
  Platform,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  findNodeHandle,
} from 'react-native';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { connect } from 'react-redux';
import { connectActionSheet } from '@expo/react-native-action-sheet';
import { withNavigation } from '@expo/ex-navigation';

import AuthTokenActions from '../redux/AuthTokenActions';
import SessionActions from '../redux/SessionActions';

import ProfileUnauthenticated from '../components/ProfileUnauthenticated';
import MyProfileContainer from '../containers/MyProfileContainer';
import OtherProfileContainer from '../containers/OtherProfileContainer';

import getViewerUsernameAsync from '../utils/getViewerUsernameAsync';
import onlyIfAuthenticated from '../utils/onlyIfAuthenticated';
import isUserAuthenticated from '../utils/isUserAuthenticated';

@connect((data, props) => ProfileScreen.getDataProps(data, props))
export default class ProfileScreen extends React.Component {
  static route = {
    navigationBar: {
      title(params) {
        if (params.username) {
          return params.username;
        } else {
          return 'Profile';
        }
      },
      ...Platform.select({
        ios: {
          renderRight: ({ params }) => {
            if (params.username) {
              return <OptionsButtonIOS />;
            } else {
              return <UserSettingsButtonIOS />;
            }
          },
        },
        android: {
          renderRight: ({ params }) => {
            if (params.username) {
              return <OptionsButtonAndroid />;
            } else {
              return <SignOutButtonAndroid />;
            }
          },
        },
      }),
    },
  };

  static getDataProps(data, props) {
    let isAuthenticated = isUserAuthenticated(data.authTokens, data.session);

    return {
      isAuthenticated,
      username: props.username,
    };
  }

  constructor(props) {
    super(props);
    this.state = {
      // NOTE: An empty username prop means to display the viewer's profile. We use null to
      // indicate we don't yet know if this is the viewer's own profile.
      isOwnProfile: !props.username ? true : null,
    };
  }

  componentDidMount() {
    if (this.state.isOwnProfile !== null) {
      return;
    }

    getViewerUsernameAsync().then(
      username => {
        this.setState({ isOwnProfile: username === this.props.username });
      },
      error => {
        this.setState({ isOwnProfile: false });
        console.warn(`There was an error fetching the viewer's username`, error);
      }
    );
  }

  render() {
    if (this.state.isOwnProfile === null) {
      return <View style={styles.loadingContainer} />;
    } else if (!this.props.isAuthenticated && this.state.isOwnProfile) {
      return <ProfileUnauthenticated />;
    } else if (this.state.isOwnProfile) {
      return <MyProfileContainer {...this.props} isOwnProfile={this.state.isOwnProfile} />;
    } else {
      return <OtherProfileContainer {...this.props} isOwnProfile={this.state.isOwnProfile} />;
    }
  }
}

@onlyIfAuthenticated
@connect()
class SignOutButtonAndroid extends React.Component {
  _anchor: View;

  render() {
    return (
      <View style={{ flex: 1 }}>
        <View
          collapsable={false}
          ref={view => {
            this._anchor = view;
          }}
          style={{ position: 'absolute', top: 5, left: 0 }}
        />
        <TouchableOpacity style={styles.buttonContainer} onPress={this._handlePress}>
          <MaterialIcons name="more-vert" size={27} color="#4E9BDE" />
        </TouchableOpacity>
      </View>
    );
  }

  _handlePress = () => {
    let handle = findNodeHandle(this._anchor);
    NativeModules.UIManager.showPopupMenu(
      handle,
      ['Sign out'],
      () => {},
      (action, selectedIndex) => {
        if (selectedIndex === 0) {
          this.props.dispatch(AuthTokenActions.clearAuthTokens());
          this.props.dispatch(SessionActions.signOut());
        }
      }
    );
  };
}

class OptionsButtonAndroid extends React.Component {
  _anchor: View;

  render() {
    return (
      <View style={{ flex: 1 }}>
        <View
          collapsable={false}
          ref={view => {
            this._anchor = view;
          }}
          style={{ position: 'absolute', top: 5, left: 0 }}
        />
        <TouchableOpacity style={styles.buttonContainer} onPress={this._handlePress}>
          <MaterialIcons name="more-vert" size={27} color="#4E9BDE" />
        </TouchableOpacity>
      </View>
    );
  }

  _handlePress = () => {
    let handle = findNodeHandle(this._anchor);
    NativeModules.UIManager.showPopupMenu(
      handle,
      ['Report this user'],
      () => {},
      (action, selectedIndex) => {
        if (selectedIndex === 0) {
          Alert.alert(
            'Thank you for your report',
            'We will investigate the case as soon as we can.'
          );
        }
      }
    );
  };
}

@onlyIfAuthenticated
@withNavigation
class UserSettingsButtonIOS extends React.Component {
  render() {
    return (
      <TouchableOpacity style={styles.buttonContainer} onPress={this._handlePress}>
        <Text style={{ fontSize: 16, color: '#4E9BDE' }}>Options</Text>
      </TouchableOpacity>
    );
  }

  _handlePress = () => {
    this.props.navigator.push('userSettings');
  };
}

@onlyIfAuthenticated
@connect()
class SignOutButtonIOS extends React.Component {
  render() {
    return (
      <TouchableOpacity style={styles.buttonContainer} onPress={this._handlePress}>
        <Text style={{ fontSize: 16, color: '#4E9BDE' }}>Sign Out</Text>
      </TouchableOpacity>
    );
  }

  _handlePress = () => {
    this.props.dispatch(AuthTokenActions.clearAuthTokens());
    this.props.dispatch(SessionActions.signOut());
  };
}

@connectActionSheet
class OptionsButtonIOS extends React.Component {
  render() {
    return (
      <TouchableOpacity style={styles.buttonContainer} onPress={this._handlePress}>
        <Ionicons name="ios-more" size={27} color="#4E9BDE" />
      </TouchableOpacity>
    );
  }

  _handlePress = () => {
    let options = ['Report this user', 'Cancel'];
    let cancelButtonIndex = 1;
    this.props.showActionSheetWithOptions(
      {
        options,
        cancelButtonIndex,
      },
      async buttonIndex => {
        if (buttonIndex === 0) {
          Alert.alert(
            'Thank you for your report',
            'We will investigate the case as soon as we can.'
          );
        }
      }
    );
  };
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
  },
  buttonContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingRight: 15,
  },
});
