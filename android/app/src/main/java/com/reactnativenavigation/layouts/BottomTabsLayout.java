package com.reactnativenavigation.layouts;

import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.RelativeLayout;

import com.aurelhubert.ahbottomnavigation.AHBottomNavigation;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.reactnativenavigation.NavigationApplication;
import com.reactnativenavigation.R;
import com.reactnativenavigation.events.EventBus;
import com.reactnativenavigation.events.ScreenChangedEvent;
import com.reactnativenavigation.params.ActivityParams;
import com.reactnativenavigation.params.FabParams;
import com.reactnativenavigation.params.LightBoxParams;
import com.reactnativenavigation.params.ScreenParams;
import com.reactnativenavigation.params.SideMenuParams;
import com.reactnativenavigation.params.SlidingOverlayParams;
import com.reactnativenavigation.params.SnackbarParams;
import com.reactnativenavigation.params.TitleBarButtonParams;
import com.reactnativenavigation.params.TitleBarLeftButtonParams;
import com.reactnativenavigation.screens.Screen;
import com.reactnativenavigation.screens.ScreenStack;
import com.reactnativenavigation.views.BottomTabs;
import com.reactnativenavigation.views.LightBox;
import com.reactnativenavigation.views.MenuButtonOnClickListener;
import com.reactnativenavigation.views.SideMenu;
import com.reactnativenavigation.views.SideMenu.Side;
import com.reactnativenavigation.views.SnackbarAndFabContainer;
import com.reactnativenavigation.views.slidingOverlay.SlidingOverlay;
import com.reactnativenavigation.views.slidingOverlay.SlidingOverlaysQueue;

import java.util.List;

import static android.view.ViewGroup.LayoutParams.MATCH_PARENT;
import static android.view.ViewGroup.LayoutParams.WRAP_CONTENT;

public class BottomTabsLayout extends BaseLayout implements AHBottomNavigation.OnTabSelectedListener, MenuButtonOnClickListener
{
    private ActivityParams params;
    private SnackbarAndFabContainer snackbarAndFabContainer;
    private BottomTabs bottomTabs;
    private ScreenStack[] screenStacks;
    private ScreenStack extraScreenStack;
    private String selectedPath;
    private final SideMenuParams leftSideMenuParams;
    private final SideMenuParams rightSideMenuParams;
    private final SlidingOverlaysQueue slidingOverlaysQueue = new SlidingOverlaysQueue();
    private @Nullable SideMenu sideMenu;
    private int currentStackIndex = 0;
    private LightBox lightBox;

    public BottomTabsLayout(AppCompatActivity activity, ActivityParams params) {
        super(activity);
        this.params = params;
		selectedPath = params.selectedPath;
        leftSideMenuParams = params.leftSideMenuParams;
        rightSideMenuParams = params.rightSideMenuParams;
        screenStacks = new ScreenStack[params.tabParams.size()];
        createLayout();
    }

    private void createLayout() {
        createSideMenu();
        createBottomTabs();
        addBottomTabs();
        addScreenStacks();
        createSnackbarContainer();
        showInitialScreenStack();
    }

    private void createSideMenu() {
        if (leftSideMenuParams == null && rightSideMenuParams == null) {
            return;
        }
        sideMenu = new SideMenu(getContext(), leftSideMenuParams, rightSideMenuParams);
        RelativeLayout.LayoutParams lp = new LayoutParams(MATCH_PARENT, MATCH_PARENT);
        addView(sideMenu, lp);
    }

    private void addScreenStacks() {
        for (int i = screenStacks.length - 1; i >= 0; i--) {
            createAndAddScreens(i);
        }

		ScreenParams screenParams = params.screenParams;
		ScreenStack newStack = new ScreenStack(getActivity(), getScreenStackParent(), screenParams.getNavigatorId(), this, this);
        if (this.selectedPath != null && this.getTabIndexForScreenId(this.selectedPath) < 0) {
			newStack.pushInitialScreen(screenParams, createScreenLayoutParams(screenParams));
		}
		extraScreenStack = newStack;
    }

    private void createAndAddScreens(int position) {
        ScreenParams screenParams = params.tabParams.get(position);
        ScreenStack newStack = new ScreenStack(getActivity(), getScreenStackParent(), screenParams.getNavigatorId(), this, this);
        newStack.pushInitialScreen(screenParams, createScreenLayoutParams(screenParams));
        screenStacks[position] = newStack;
    }

    public RelativeLayout getScreenStackParent() {
        return sideMenu == null ? this : sideMenu.getContentContainer();
    }

    @NonNull
    private LayoutParams createScreenLayoutParams(ScreenParams params) {
        LayoutParams lp = new LayoutParams(MATCH_PARENT, MATCH_PARENT);
        if (params.styleParams.drawScreenAboveBottomTabs) {
			lp.bottomMargin = (int) getResources().getDimension(R.dimen.overlap);
            lp.addRule(RelativeLayout.ABOVE, bottomTabs.getId());
        }
        return lp;
    }

    private void createBottomTabs() {
        bottomTabs = new BottomTabs(getContext());
        bottomTabs.addTabs(params.tabParams, this);
    }

    private void addBottomTabs() {
        LayoutParams lp = new LayoutParams(MATCH_PARENT, WRAP_CONTENT);
        lp.addRule(ALIGN_PARENT_BOTTOM);
        getScreenStackParent().addView(bottomTabs, lp);
    }

    private void createSnackbarContainer() {
        snackbarAndFabContainer = new SnackbarAndFabContainer(getContext(), this);
        RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT);
        lp.addRule(ABOVE, bottomTabs.getId());
        snackbarAndFabContainer.setClickable(false);
        getScreenStackParent().addView(snackbarAndFabContainer, lp);
    }

    private void showInitialScreenStack() {
		int initialScreen = 0;

		if (this.selectedPath != null) {
			initialScreen = getTabIndexForScreenId(this.selectedPath);
		}

		if (initialScreen > -1) {
			showStackAndUpdateStyle(screenStacks[initialScreen]);
			EventBus.instance.post(new ScreenChangedEvent(screenStacks[initialScreen].peek().getScreenParams()));
		} else if (this.selectedPath != null && initialScreen < 0) {
			showStackAndUpdateStyle(extraScreenStack);
		}

		bottomTabs.setCurrentItem(initialScreen);
    }

	private int getTabIndexForScreenId(String path)
	{
		int leni = screenStacks.length;

		for (int i = 0; i < leni; ++i)
		{
			ScreenStack stack = screenStacks[i];

			if (stack.rootScreenId().equals(path)) {
				return i;
			}
		}

		return -1;
	}

	@Override
    public View asView() {
        return this;
    }

    @Override
    public boolean onBackPressed() {
        if (getCurrentScreenStack().handleBackPressInJs()) {
            return true;
        }

        if (getCurrentScreenStack().canPop()) {
            getCurrentScreenStack().pop(true);
            setBottomTabsStyleFromCurrentScreen();
            EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
            return true;
        } else {
            return getCurrentScreenStack().getDisableBackNavigation();
        }
    }

    @Override
    public void setTopBarVisible(String screenInstanceId, boolean hidden, boolean animated) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setScreenTopBarVisible(screenInstanceId, hidden, animated);
        }
    }

    public void setBottomTabsVisible(boolean hidden, boolean animated) {
        bottomTabs.setVisibility(hidden, animated);
    }

    @Override
    public void setTitleBarTitle(String screenInstanceId, String title) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setScreenTitleBarTitle(screenInstanceId, title);
        }
		if (extraScreenStack != null) {
			extraScreenStack.setScreenTitleBarTitle(screenInstanceId, title);
		}
    }

    @Override
    public void setTitleBarSubtitle(String screenInstanceId, String subtitle) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setScreenTitleBarSubtitle(screenInstanceId, subtitle);
        }
        if (extraScreenStack != null) {
			extraScreenStack.setScreenTitleBarSubtitle(screenInstanceId, subtitle);
		}
    }

    @Override
    public void setTitleBarRightButtons(String screenInstanceId, String navigatorEventId, List<TitleBarButtonParams> titleBarButtons) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setScreenTitleBarRightButtons(screenInstanceId, navigatorEventId, titleBarButtons);
        }
        if (extraScreenStack != null) {
			extraScreenStack.setScreenTitleBarRightButtons(screenInstanceId, navigatorEventId, titleBarButtons);
		}
    }

    @Override
    public void setTitleBarLeftButton(String screenInstanceId, String navigatorEventId, TitleBarLeftButtonParams titleBarLeftButtonParams) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setScreenTitleBarLeftButton(screenInstanceId, navigatorEventId, titleBarLeftButtonParams);
        }
        if (extraScreenStack != null) {
			extraScreenStack.setScreenTitleBarLeftButton(screenInstanceId, navigatorEventId, titleBarLeftButtonParams);
		}
    }

    @Override
    public void setFab(String screenInstanceId, String navigatorEventId, FabParams fabParams) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].setFab(screenInstanceId, fabParams);
        }
        if (extraScreenStack != null) {
			extraScreenStack.setFab(screenInstanceId, fabParams);
		}
    }

    @Override
    public void updateScreenStyle(String screenInstanceId, Bundle styleParams) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].updateScreenStyle(screenInstanceId, styleParams);
        }
        if (extraScreenStack != null) {
			extraScreenStack.updateScreenStyle(screenInstanceId, styleParams);
		}
    }

    @Override
    public String getCurrentlyVisibleScreenId() {
        return getCurrentScreen().getScreenParams().getScreenId();
    }

    @Override
    public void selectTopTabByTabIndex(String screenInstanceId, int index) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].selectTopTabByTabIndex(screenInstanceId, index);
        }
        if (extraScreenStack != null) {
			extraScreenStack.selectTopTabByTabIndex(screenInstanceId, index);
		}
    }

    @Override
    public void selectTopTabByScreen(String screenInstanceId) {
        for (int i = 0; i < bottomTabs.getItemsCount(); i++) {
            screenStacks[i].selectTopTabByScreen(screenInstanceId);
        }
        if (extraScreenStack != null) {
			extraScreenStack.selectTopTabByScreen(screenInstanceId);
		}
    }

    @Override
    public void toggleSideMenuVisible(boolean animated, Side side) {
        if (sideMenu != null) {
            sideMenu.toggleVisible(animated, side);
        }
    }

    @Override
    public void setSideMenuVisible(boolean animated, boolean visible, Side side) {
        if (sideMenu != null) {
            sideMenu.setVisible(visible, animated, side);
        }
    }

    @Override
    public void disableOpenGesture(boolean disableOpenGesture)
    {
        if (sideMenu != null) {
            sideMenu.disableOpenGesture(disableOpenGesture);
        }
    }

	@Override
	public void disableBackNavigation(boolean disableBackNavigation)
	{
		getCurrentScreenStack().setDisableBackNavigation(disableBackNavigation);
	}

	@Override
    public void showSnackbar(SnackbarParams params) {
        final String eventId = getCurrentScreenStack().peek().getNavigatorEventId();
        snackbarAndFabContainer.showSnackbar(eventId, params);
    }

    @Override
    public void dismissSnackbar() {
        snackbarAndFabContainer.dismissSnackbar();
    }

    @Override
    public void showLightBox(LightBoxParams params) {
        if (lightBox == null) {
            lightBox = new LightBox(getActivity(), new Runnable() {
                @Override
                public void run() {
                    lightBox = null;
                }
            }, params);
            lightBox.show();
        }
    }

    @Override
    public void dismissLightBox() {
        if (lightBox != null) {
            lightBox.hide();
            lightBox = null;
        }
    }

    @Override
    public void showSlidingOverlay(final SlidingOverlayParams params) {
        slidingOverlaysQueue.add(new SlidingOverlay(this, params));
    }

    @Override
    public void hideSlidingOverlay() {
        slidingOverlaysQueue.remove();
    }

    @Override
    public void onModalDismissed() {
        EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
    }

    @Override
    public boolean containsNavigator(String navigatorId) {
        // Unused
        return false;
    }

    @Override
    public Screen getCurrentScreen() {
        return getCurrentScreenStack().peek();
    }

    public void selectBottomTabByTabIndex(Integer index) {
		boolean wasSelected = bottomTabs.getCurrentItem() == index;
        bottomTabs.setCurrentItem(index, false);
		this.onTabSelected(index, wasSelected, false);
    }

    public void selectBottomTabByNavigatorId(String navigatorId) {
        bottomTabs.setCurrentItem(getScreenStackIndex(navigatorId));
    }

    @Override
    public void push(ScreenParams params) {
        ScreenStack screenStack = getScreenStack(params.getNavigatorId());
        screenStack.push(params, createScreenLayoutParams(params));
        if (isCurrentStack(screenStack)) {
            bottomTabs.setStyleFromScreen(params.styleParams);
            EventBus.instance.post(new ScreenChangedEvent(params));
        }
    }

    @Override
    public void pop(ScreenParams params) {
        getCurrentScreenStack().pop(params.animateScreenTransitions, new ScreenStack.OnScreenPop() {
            @Override
            public void onScreenPopAnimationEnd() {
                setBottomTabsStyleFromCurrentScreen();
                EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
            }
        });
    }

    @Override
    public void popToRoot(ScreenParams params) {
        getCurrentScreenStack().popToRoot(params.animateScreenTransitions, new ScreenStack.OnScreenPop() {
            @Override
            public void onScreenPopAnimationEnd() {
                setBottomTabsStyleFromCurrentScreen();
                EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
            }
        });
    }

    @Override
    public void newStack(final ScreenParams params) {
        ScreenStack screenStack = getScreenStack(params.getNavigatorId());
        screenStack.newStack(params, createScreenLayoutParams(params));
        if (isCurrentStack(screenStack)) {
            bottomTabs.setStyleFromScreen(params.styleParams);
            EventBus.instance.post(new ScreenChangedEvent(params));
        }
    }

    public void destroyStacks() {
		if (screenStacks != null) {
			for (ScreenStack screenStack : screenStacks) {
				screenStack.destroy();
			}
		}

		screenStacks = null;
	}

    @Override
    public void destroy() {
		snackbarAndFabContainer.destroy();
		destroyStacks();
        if (sideMenu != null) {
            sideMenu.destroy();
        }
        if (lightBox != null) {
            lightBox.destroy();
            lightBox = null;
        }
        slidingOverlaysQueue.destroy();
    }

    @Override
    public boolean onTabSelected(int position, boolean wasSelected) {
        return this.onTabSelected(position, wasSelected, true);
    }

    private boolean onTabSelected(int position, boolean wasSelected, boolean sendEventToJS) {
		if (wasSelected && sendEventToJS) {
			sendTabReselectedEventToJs();
			return false;
		}

		final int unselectedTabIndex = currentStackIndex;
		hideCurrentStack();
		showNewStack(position);
		EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
		if (sendEventToJS) {
			sendTabSelectedEventToJs(position, unselectedTabIndex);
		}
		return true;
	}

    private void sendTabSelectedEventToJs(int selectedTabIndex, int unselectedTabIndex) {
        String navigatorEventId = getCurrentScreenStack().peek().getNavigatorEventId();
        WritableMap data = createTabSelectedEventData(selectedTabIndex, unselectedTabIndex);
        NavigationApplication.instance.getEventEmitter().sendNavigatorEvent("bottomTabSelected", navigatorEventId, data);

        data = createTabSelectedEventData(selectedTabIndex, unselectedTabIndex);
        NavigationApplication.instance.getEventEmitter().sendNavigatorEvent("bottomTabSelected", data);
    }

    private WritableMap createTabSelectedEventData(int selectedTabIndex, int unselectedTabIndex) {
        WritableMap data = Arguments.createMap();
        data.putInt("selectedTabIndex", selectedTabIndex);
        data.putInt("unselectedTabIndex", unselectedTabIndex);
        return data;
    }

    private void sendTabReselectedEventToJs() {
        WritableMap data = Arguments.createMap();
        String navigatorEventId = getCurrentScreenStack().peek().getNavigatorEventId();
        NavigationApplication.instance.getEventEmitter().sendNavigatorEvent("bottomTabReselected", navigatorEventId, data);
    }

    private void showNewStack(int position) {
		if (position > -1) {
			showStackAndUpdateStyle(screenStacks[position]);
			currentStackIndex = position;
		} else {
			showStackAndUpdateStyle(extraScreenStack);
			currentStackIndex = -1;
		}
    }

    private void showStackAndUpdateStyle(ScreenStack newStack) {
        newStack.show();
        bottomTabs.setStyleFromScreen(newStack.getCurrentScreenStyleParams());
    }

    private void hideCurrentStack() {
        ScreenStack currentScreenStack = getCurrentScreenStack();
        currentScreenStack.hide();
    }

    private ScreenStack getCurrentScreenStack() {
        return currentStackIndex > -1 ? screenStacks[currentStackIndex] : extraScreenStack;
    }

    private @NonNull ScreenStack getScreenStack(String navigatorId) {
        int index = getScreenStackIndex(navigatorId);
        return index > -1 ? screenStacks[index] : extraScreenStack;
    }

    public void setBottomTabButtonByIndex(Integer index, ScreenParams params) {
        bottomTabs.setTabButton(params, index);
    }

    public void setBottomTabButtonByNavigatorId(String navigatorId, ScreenParams params) {
        bottomTabs.setTabButton(params, getScreenStackIndex(navigatorId));
    }

    private int getScreenStackIndex(String navigatorId) throws ScreenStackNotFoundException {
        for (int i = 0; i < screenStacks.length; i++) {
            if (screenStacks[i].getNavigatorId().equals(navigatorId)) {
                return i;
            }
        }
        if (extraScreenStack != null) {
			return -1;
		}
        throw new ScreenStackNotFoundException("Stack " + navigatorId + " not found");
    }

	public void showScreen(ScreenParams screenParams)
	{
	    hideCurrentStack();
	    if (!extraScreenStack.empty() && !extraScreenStack.bottom().getScreenParams().screenId.equals(screenParams.screenId))
        {
            extraScreenStack.destroy();
            extraScreenStack.pushInitialScreen(screenParams, createScreenLayoutParams(screenParams));
        } else if (extraScreenStack.empty()) {
            extraScreenStack.pushInitialScreen(screenParams, createScreenLayoutParams(screenParams));
        }
        showNewStack(-1);
		bottomTabs.setCurrentItem(-1, false);
	}

	private class ScreenStackNotFoundException extends RuntimeException {
        ScreenStackNotFoundException(String navigatorId) {
            super(navigatorId);
        }
    }

    private boolean isCurrentStack(ScreenStack screenStack) {
        return getCurrentScreenStack() == screenStack;
    }

    private void setBottomTabsStyleFromCurrentScreen() {
        bottomTabs.setStyleFromScreen(getCurrentScreenStack().getCurrentScreenStyleParams());
    }

    @Override
    public boolean onTitleBarBackButtonClick() {
        if (getCurrentScreenStack().canPop()) {
            getCurrentScreenStack().pop(true, new ScreenStack.OnScreenPop() {
                @Override
                public void onScreenPopAnimationEnd() {
                    setBottomTabsStyleFromCurrentScreen();
                    EventBus.instance.post(new ScreenChangedEvent(getCurrentScreenStack().peek().getScreenParams()));
                }
            });
            return true;
        }
        return false;
    }

    @Override
    public void onSideMenuButtonClick(Side side) {
        final String navigatorEventId = getCurrentScreenStack().peek().getNavigatorEventId();
        NavigationApplication.instance.getEventEmitter().sendNavigatorEvent("sideMenu", navigatorEventId);
        if (sideMenu != null) {
            sideMenu.openDrawer(side);
        }
    }

	@Override
	public void setSideMenu(SideMenu sideMenu)
	{
		this.sideMenu = sideMenu;
	}

	@Override
	public SideMenu getSideMenu()
	{
		return sideMenu;
	}
}
